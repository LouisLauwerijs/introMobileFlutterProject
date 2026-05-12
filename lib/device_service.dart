import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';
import 'device_model.dart';

/// Deze 'Service' regelt alle communicatie met de database (Firestore).
/// Je kunt dit zien als de postbode die gegevens van en naar de online opslag brengt.
class DeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // De toegang tot de database
  final FirebaseAuth _auth = FirebaseAuth.instance;               // De toegang tot de ingelogde gebruiker

  // Functie om een nieuw apparaat toe te voegen aan de app
  Future<void> addDevice({
    required String name,
    required String description,
    required String category,
    required XFile imageFile,
    required double price,
    required GeoPoint location,
    required String city,
    required String locationName,
  }) async {
    try {
      // Het unieke nummer van de ingelogde gebruiker ophalen
      String uid = _auth.currentUser!.uid;

      // De naam van de verhuurder ophalen uit de 'users' collectie
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String ownerName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Onbekende verhuurder';

      // Een nieuw, uniek nummer voor dit apparaat laten aanmaken
      String deviceId = _firestore.collection('devices').doc().id;

      // De geselecteerde foto omzetten naar een lange tekst (Base64).
      // Hierdoor hoeven we geen aparte opslagdienst (zoals Firebase Storage) te gebruiken.
      final bytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(bytes);
      String photoUrl = 'data:image/jpeg;base64,$base64Image';

      // Alle gegevens opslaan in de database (Firestore)
      await _firestore.collection('devices').doc(deviceId).set({
        'ownerId': uid,
        'ownerName': ownerName,
        'name': name,
        'description': description,
        'category': category,
        'photoUrl': photoUrl,
        'price': price,
        'isAvailable': true, // Standaard is een nieuw apparaat direct beschikbaar
        'location': location,
        'city': city,
        'locationName': locationName,
        'createdAt': FieldValue.serverTimestamp(), // De tijd van opslaan automatisch toevoegen
      });
    } catch (e) {
      // Als er iets fout gaat, laten we dat weten in de logs
      print('Fout bij toevoegen apparaat: $e');
      rethrow;
    }
  }

  // Functie voor de eigenaar om de inlevering goed te keuren
  Future<void> approveReturn(String rentalId, String deviceId, bool makeAvailable) async {
    try {
      // 1. Markeer de huur als 'returned' (voltooid en ingeleverd)
      await _firestore.collection('rentals').doc(rentalId).update({
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update de beschikbaarheid van het apparaat
      await updateAvailability(deviceId, makeAvailable);

      // 3. Verwijder alle berichten van deze chat (omdat het item is ingeleverd)
      final messagesSnap = await _firestore.collection('rentals').doc(rentalId).collection('messages').get();
      for (var doc in messagesSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Verwijder alle bericht-meldingen gerelateerd aan deze huur
      final notifySnap = await _firestore.collection('notifications')
          .where('rentalId', isEqualTo: rentalId)
          .where('type', isEqualTo: 'message')
          .get();
      for (var doc in notifySnap.docs) {
        await doc.reference.delete();
      }
      
    } catch (e) {
      print('Fout bij goedkeuren inlevering: $e');
      rethrow;
    }
  }

  // Functie om de lijst met apparaten op te halen (met filters)
  Stream<List<Device>> getDevices({String? category, String? city, bool onlyAvailable = false}) {
    // We beginnen bij de verzameling 'devices' in de database
    Query query = _firestore.collection('devices');

    // Als we alleen beschikbare toestellen willen (voor het dashboard)
    if (onlyAvailable) {
      query = query.where('isAvailable', isEqualTo: true);
    }

    // Als er een specifieke categorie is gekozen, filteren we daarop via de database
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    // We halen de gegevens op en filteren de stad in de app zelf.
    // Dit zorgt ervoor dat "Antwerpen" ook gevonden wordt als je "antwerpen" of "ant" typt.
    return query.snapshots().map((snapshot) {
      // Zet de database-gegevens om naar een lijst met Apparaten
      var devices = snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList();
      
      // Als de gebruiker een stad heeft ingevoerd, filteren we de lijst handmatig
      if (city != null && city.isNotEmpty) {
        devices = devices.where((device) {
          return device.city.toLowerCase().contains(city.toLowerCase());
        }).toList();
      }
      
      return devices;
    });
  }

  // Functie om aan te passen of een apparaat nog beschikbaar is of niet
  Future<void> updateAvailability(String deviceId, bool isAvailable) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'isAvailable': isAvailable,
    });
  }

  // Functie om een apparaat te verwijderen (unlisten)
  Future<void> deleteDevice(String deviceId) async {
    try {
      await _firestore.collection('devices').doc(deviceId).delete();
    } catch (e) {
      print('Fout bij verwijderen apparaat: $e');
      rethrow;
    }
  }

  // Functie om een aanvraag te doen om een apparaat te huren
  Future<void> requestRental({
    required String deviceId,
    required String deviceName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;
      
      // De naam van de huurder ophalen
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String renterName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Anonieme huurder';

      // De gegevens van het apparaat ophalen om de ownerId te weten
      DocumentSnapshot deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      String ownerId = (deviceDoc.data() as Map<String, dynamic>?)?['ownerId'] ?? '';

      // We voegen de aanvraag toe aan de 'rentals' collectie met status 'pending'
      await _firestore.collection('rentals').add({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'renterId': uid,
        'renterName': renterName,
        'ownerId': ownerId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'totalPrice': totalPrice,
        'status': 'pending', // Wacht op goedkeuring
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Belangrijk: We zetten het toestel nog NIET op onbeschikbaar. 
      // Dat gebeurt pas na acceptatie.
      
    } catch (e) {
      print('Fout bij aanvragen huur: $e');
      rethrow;
    }
  }

  // Functie voor de eigenaar om een aanvraag te accepteren of te weigeren
  Future<void> handleRentalRequest(String rentalId, String deviceId, bool accept) async {
    try {
      if (accept) {
        // 1. Update de status naar 'accepted'
        await _firestore.collection('rentals').doc(rentalId).update({
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        // 2. Zet het apparaat op onbeschikbaar
        await updateAvailability(deviceId, false);
      } else {
        // Update de status naar 'denied'
        await _firestore.collection('rentals').doc(rentalId).update({
          'status': 'denied',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Fout bij afhandelen aanvraag: $e');
      rethrow;
    }
  }

  // Functie om alle huren van de huidige gebruiker op te halen (geaccepteerd of teruggebracht voor de geschiedenis)
  Stream<List<Map<String, dynamic>>> getUserRentals() {
    String uid = _auth.currentUser!.uid;
    return _firestore
        .collection('rentals')
        .where('renterId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'returned'])
        .snapshots()
        .map((snapshot) {
      final rentals = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      rentals.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      return rentals;
    });
  }

  // Functie om alle meldingen en aanvragen op te halen
  Stream<List<Map<String, dynamic>>> getNotifications() {
    String uid = _auth.currentUser!.uid;
    
    // We combineren:
    // 1. Aanvragen en status-updates uit de 'rentals' collectie (on-the-fly)
    // 2. Nieuwe berichten uit de 'notifications' collectie
    return Rx.combineLatest2(
      _firestore.collection('rentals').snapshots(),
      _firestore.collection('notifications').where('receiverId', isEqualTo: uid).snapshots(),
      (QuerySnapshot rentalSnap, QuerySnapshot notifySnap) {
        List<Map<String, dynamic>> notifications = [];
        DateTime nu = DateTime.now();

        // --- DEEL 1: RENTALS LOGICA (bestaand) ---
        final allRentals = rentalSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        for (var item in allRentals) {
          String status = item['status'] ?? 'pending';
          DateTime? start = (item['startDate'] as Timestamp?)?.toDate();
          DateTime? eind = (item['endDate'] as Timestamp?)?.toDate();

          if (item['ownerId'] == uid && status == 'pending') {
            notifications.add({
              ...item,
              'type': 'incoming_request',
              'msg': '${item['renterName']} wilt je ${item['deviceName']} huren.',
              'sortDate': item['createdAt'],
            });
          }

          if (item['renterId'] == uid && (status == 'accepted' || status == 'denied')) {
            notifications.add({
              ...item,
              'type': 'request_response',
              'msg': 'Je aanvraag voor ${item['deviceName']} is ${status == 'accepted' ? 'geaccepteerd!' : 'geweigerd.'}',
              'sortDate': item['respondedAt'] ?? item['createdAt'],
            });
          }

          if (status == 'accepted' && start != null && eind != null) {
            if (start.day == nu.day && start.month == nu.month && start.year == nu.year) {
              notifications.add({
                ...item,
                'type': 'date_alert',
                'msg': 'Vandaag begint de huur van ${item['deviceName']}!',
                'sortDate': Timestamp.fromDate(start),
              });
            }
            if (eind.day == nu.day && eind.month == nu.month && eind.year == nu.year) {
              notifications.add({
                ...item,
                'type': 'date_alert',
                'msg': 'Vandaag is de laatste dag voor de huur van ${item['deviceName']}.',
                'sortDate': Timestamp.fromDate(eind),
              });
            }
          }
        }

        // --- DEEL 2: BERICHTEN LOGICA (nieuw) ---
        for (var doc in notifySnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          notifications.add({
            ...data,
            'id': doc.id,
            'type': 'message',
            'msg': 'Nieuw bericht van ${data['senderName']}: ${data['text']}',
            'sortDate': data['createdAt'],
          });
        }

        // Sorteer op datum (nieuwste eerst)
        notifications.sort((a, b) {
          final aDate = a['sortDate'] as Timestamp?;
          final bDate = b['sortDate'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });

        return notifications;
      },
    );
  }

  // --- CHAT FUNCTIES ---

  // Functie om een bericht te versturen
  Future<void> sendMessage({
    required String rentalId,
    required String text,
    required String receiverId,
    required String deviceName,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;
      
      // Naam van de verzender ophalen
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String senderName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Iemand';

      // 1. Bericht opslaan in een subcollectie van de huur
      await _firestore.collection('rentals').doc(rentalId).collection('messages').add({
        'senderId': uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Een melding aanmaken voor de ontvanger
      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'senderName': senderName,
        'deviceName': deviceName,
        'rentalId': rentalId,
        'text': text,
        'type': 'message',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Fout bij versturen bericht: $e');
      rethrow;
    }
  }

  // Stream om berichten van een specifieke huur op te halen
  Stream<QuerySnapshot> getMessages(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Functie om een actieve huur/aanvraag te vinden en info over de andere partij te krijgen
  Future<Map<String, dynamic>?> findActiveRentalInfo(String deviceId) async {
    String uid = _auth.currentUser!.uid;
    
    // Zoek naar een huur waar de huidige gebruiker de huurder is voor dit toestel (niet returned)
    final snap = await _firestore
        .collection('rentals')
        .where('deviceId', isEqualTo: deviceId)
        .where('renterId', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(1)
        .get();
        
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      return {
        'rentalId': doc.id,
        'otherUserId': doc.data()['ownerId'],
      };
    }
    
    // Als huurder niks gevonden, ben je misschien de eigenaar?
    final snapOwner = await _firestore
        .collection('rentals')
        .where('deviceId', isEqualTo: deviceId)
        .where('ownerId', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(1)
        .get();

    if (snapOwner.docs.isNotEmpty) {
      final doc = snapOwner.docs.first;
      return {
        'rentalId': doc.id,
        'otherUserId': doc.data()['renterId'],
      };
    }

    return null;
  }

  // Functie om alle huren te zien die ANDEREN bij JOU hebben gedaan (geaccepteerd of teruggebracht)
  Stream<List<Map<String, dynamic>>> getOwnerRentals() {
    String uid = _auth.currentUser!.uid;
    return _firestore
        .collection('rentals')
        .where('ownerId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'returned'])
        .snapshots()
        .map((snapshot) {
      final rentals = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      rentals.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      return rentals;
    });
  }

  // Functie om een recensie toe te voegen
  Future<void> addReview({
    required String rentalId,
    required String deviceId,
    required int rating,
    required String comment,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;

      // De naam van de huurder ophalen
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String renterName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Anoniem';

      // Haal ownerId op van het apparaat
      DocumentSnapshot deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      String ownerId = (deviceDoc.data() as Map<String, dynamic>?)?['ownerId'] ?? '';

      // 1. Voeg de recensie toe aan een nieuwe collectie 'reviews'
      await _firestore.collection('reviews').add({
        'rentalId': rentalId,
        'deviceId': deviceId,
        'renterId': uid,
        'ownerId': ownerId,
        'renterName': renterName,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Markeer de huur als 'beoordeeld' zodat de knop verdwijnt
      await _firestore.collection('rentals').doc(rentalId).update({
        'hasReview': true,
      });
    } catch (e) {
      print('Fout bij toevoegen recensie: $e');
      rethrow;
    }
  }

  // Functie om een specifieke huur te verwijderen uit de geschiedenis
  Future<void> deleteRental(String rentalId, String deviceId) async {
    try {
      // 1. Verwijder de huur uit de 'rentals' collectie
      await _firestore.collection('rentals').doc(rentalId).delete();

      // 2. Zet het apparaat weer op 'beschikbaar' zodat anderen het kunnen zien
      await updateAvailability(deviceId, true);
    } catch (e) {
      print('Fout bij verwijderen huur: $e');
      rethrow;
    }
  }

  // Functie om een reservatie te annuleren
  Future<void> cancelRental(String rentalId, String deviceId) async {
    try {
      // 1. Verwijder de huur uit de 'rentals' collectie
      await _firestore.collection('rentals').doc(rentalId).delete();

      // 2. Zet het apparaat weer op 'beschikbaar'
      await updateAvailability(deviceId, true);
    } catch (e) {
      print('Fout bij annuleren huur: $e');
      rethrow;
    }
  }

  // Functie om één specifiek apparaat op te halen via ID
  Future<Device?> getDeviceById(String deviceId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('devices').doc(deviceId).get();
      if (doc.exists) {
        return Device.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Fout bij ophalen apparaat: $e');
      return null;
    }
  }

  // Functie om recensies van een specifiek apparaat op te halen
  Stream<List<Map<String, dynamic>>> getDeviceReviews(String deviceId) {
    return _firestore
        .collection('reviews')
        .where('deviceId', isEqualTo: deviceId)
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs.map((doc) => doc.data()).toList();
      reviews.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });
      return reviews;
    });
  }

  // Functie om ALLE recensies op te halen die over JOUW toestellen gaan
  Stream<List<Map<String, dynamic>>> getOwnerReviews(String ownerId) {
    return _firestore
        .collection('reviews')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
