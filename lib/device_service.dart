import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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

  // Functie om een apparaat te huren voor een bepaalde periode
  Future<void> rentDevice({
    required String deviceId,
    required String deviceName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;

      // De gegevens van het apparaat ophalen om de ownerId te weten
      DocumentSnapshot deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      String ownerId = (deviceDoc.data() as Map<String, dynamic>?)?['ownerId'] ?? '';

      // 1. Voeg de huur toe aan de 'rentals' collectie
      await _firestore.collection('rentals').add({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'renterId': uid,
        'ownerId': ownerId, // We slaan ook de eigenaar op
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'totalPrice': totalPrice,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Zet het apparaat op 'niet beschikbaar' zodat het van het dashboard verdwijnt
      await updateAvailability(deviceId, false);
      
    } catch (e) {
      print('Fout bij huren apparaat: $e');
      rethrow;
    }
  }

  // Functie om alle gehuurde items van de huidige gebruiker op te halen
  Stream<List<Map<String, dynamic>>> getUserRentals() {
    String uid = _auth.currentUser!.uid;
    return _firestore
        .collection('rentals')
        .where('renterId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final rentals = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sorteren op datum (nieuwste eerst)
      rentals.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      return rentals;
    });
  }

  // Functie om alle huren te zien die ANDEREN bij JOU hebben gedaan
  Stream<List<Map<String, dynamic>>> getOwnerRentals() {
    String uid = _auth.currentUser!.uid;
    return _firestore
        .collection('rentals')
        .where('ownerId', isEqualTo: uid)
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

      // 1. Voeg de recensie toe aan een nieuwe collectie 'reviews'
      await _firestore.collection('reviews').add({
        'rentalId': rentalId,
        'deviceId': deviceId,
        'renterId': uid,
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
  Future<void> deleteRental(String rentalId) async {
    await _firestore.collection('rentals').doc(rentalId).delete();
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
}
