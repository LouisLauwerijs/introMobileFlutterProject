import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'secrets.dart';
import 'device_service.dart';

/// Dit is de pagina waar je een nieuw apparaat kunt aanbieden voor de verhuur.
/// De gebruiker kan hier alle details invullen, een foto kiezen en de locatie ophalen.
class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  // Controleurs om de ingevoerde tekst uit de velden te lezen
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  
  // Standaardwaarden voor het formulier
  String _category = 'Gereedschap';
  XFile? _imageFile;
  Position? _currentPosition;
  String _city = '';
  String _locationName = '';
  bool _isLoading = false; // Laat een draaiend wieltje zien tijdens het opslaan

  // De API sleutel wordt nu veilig geladen uit het secrets.dart bestand
  final String _googleApiKey = Secrets.googleMapsApiKey;

  // De lijst met categorieën waaruit de gebruiker kan kiezen
  final List<String> _categories = [
    'Gereedschap',
    'Tuin',
    'Keuken',
    'Elektronica',
    'Vervoer',
    'Overig',
  ];

  // Functie om de galerij te openen en een foto te kiezen
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Maak de foto kleiner om de database niet te zwaar te maken
      maxHeight: 800,
      imageQuality: 70, // Verminder de kwaliteit een beetje om de tekst korter te maken
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  // Functie die locatiegegevens zoekt bij GPS-coördinaten via Google Maps
  Future<Map<String, String>> _getLocationDetailsFromCoordinates(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          String fullAddress = results.isNotEmpty ? results[0]['formatted_address'] : 'Onbekend adres';
          String city = 'Onbekend';

          for (var result in results) {
            final addressComponents = result['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('locality')) {
                city = component['long_name'];
                break;
              }
            }
            if (city != 'Onbekend') break;
          }
          return {'city': city, 'address': fullAddress};
        }
      }
    } catch (e) {
      print('Google Geocoding error: $e');
    }
    return {'city': 'Onbekend', 'address': 'Onbekend adres'};
  }

  // Functie om de huidige GPS-locatie van de telefoon op te vragen
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Controleren of de locatie-instelling aan staat op de telefoon
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locatieservices zijn uitgeschakeld.')),
      );
      return;
    }

    // Vragen om toestemming voor het gebruik van de locatie
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locatiepermissie geweigerd.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      Map<String, String> details = await _getLocationDetailsFromCoordinates(position.latitude, position.longitude);

      setState(() {
        _currentPosition = position;
        _city = details['city']!;
        _locationName = details['address']!;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Location error: $e');
    }
  }

  // Functie die alle gegevens verzamelt en verstuurt naar de database
  Future<void> _submit() async {
    // Controleren of alle velden zijn ingevuld en of er een foto en locatie is
    if (_formKey.currentState!.validate() && _imageFile != null && _currentPosition != null) {
      setState(() => _isLoading = true);
      try {
        await DeviceService().addDevice(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _category,
          imageFile: _imageFile!,
          price: double.parse(_priceController.text),
          location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          city: _city,
          locationName: _locationName,
        );
        Navigator.pop(context); // Terug naar het overzicht na succesvol toevoegen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij opslaan: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Melding geven als er iets ontbreekt
      String message = 'Controleer of je een naam, foto en locatie hebt toegevoegd.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toestel Verhuren')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Wieltje laten draaien tijdens het laden
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Naam van het toestel'),
                      validator: (value) => value == null || value.isEmpty ? 'Vul een naam in' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Beschrijving'),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty ? 'Vul een beschrijving in' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Categorie'),
                      items: _categories.map((String category) {
                        return DropdownMenuItem(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (value) => setState(() => _category = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Prijs per dag (€)'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Vul een prijs in' : null,
                    ),
                    const SizedBox(height: 20),
                    // Foto kiezen of de geselecteerde foto laten zien
                    _imageFile == null
                        ? ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: const Text('Kies Foto'),
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 150,
                                child: kIsWeb
                                    ? Image.network(_imageFile!.path)
                                    : Image.file(io.File(_imageFile!.path)),
                              ),
                              TextButton(onPressed: _pickImage, child: const Text('Wijzig Foto')),
                            ],
                          ),
                    const SizedBox(height: 20),
                    // Knop om locatie op te halen of de stadnaam laten zien
                    _currentPosition == null
                        ? ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.location_on),
                            label: const Text('Haal Locatie Op'),
                          )
                        : Row(
                            children: [
                              const Icon(Icons.check, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('Locatie: $_city'),
                              const Spacer(),
                              TextButton(onPressed: _getCurrentLocation, child: const Text('Vernieuw')),
                            ],
                          ),
                    const SizedBox(height: 32),
                    // De knop om alles definitief op te slaan
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Toestel Toevoegen'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
