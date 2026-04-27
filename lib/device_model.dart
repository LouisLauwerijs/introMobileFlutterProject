import 'package:cloud_firestore/cloud_firestore.dart';

/// Dit bestand beschrijft hoe een 'Apparaat' (Device) eruit ziet in onze app.
/// Je kunt het zien als een digitaal paspoort voor elk toestel dat wordt aangeboden.
class Device {
  final String id;             // Het unieke nummer van dit apparaat in de database
  final String ownerId;        // Het unieke nummer van de persoon die dit apparaat verhuurt
  final String ownerName;      // De naam van de persoon die dit apparaat verhuurt
  final String name;           // De naam van het apparaat (bijv. "Boormachine")
  final String description;    // Een korte uitleg over het apparaat
  final String category;       // De categorie (bijv. "Gereedschap" of "Keuken")
  final String photoUrl;       // De afbeelding van het apparaat (als tekst opgeslagen)
  final double price;          // De prijs per dag
  final bool isAvailable;      // Is het apparaat op dit moment beschikbaar? (Ja/Nee)
  final GeoPoint location;     // De exacte GPS-coördinaten van het apparaat
  final String city;           // De stad waar het apparaat zich bevindt
  final String locationName;   // De volledige adresnaam van de locatie

  // Dit is de 'constructeur': die vertelt de app dat al deze gegevens verplicht zijn
  Device({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.description,
    required this.category,
    required this.photoUrl,
    required this.price,
    required this.isAvailable,
    required this.location,
    required this.city,
    required this.locationName,
  });

  // Deze functie zet een apparaat om in een formaat dat de database begrijpt
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'name': name,
      'description': description,
      'category': category,
      'photoUrl': photoUrl,
      'price': price,
      'isAvailable': isAvailable,
      'location': location,
      'city': city,
      'locationName': locationName,
    };
  }

  // Deze functie doet het omgekeerde: het haalt gegevens uit de database en maakt er een 'Apparaat' van voor de app
  factory Device.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Device(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? 'Onbekende verhuurder',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      location: data['location'] ?? const GeoPoint(0, 0),
      city: data['city'] ?? '',
      locationName: data['locationName'] ?? '',
    );
  }
}
