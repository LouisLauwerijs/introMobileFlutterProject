import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'secrets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCurrency = 'EUR';
  bool _isLoading = false;
  
  // Locatie data
  double? _lat;
  double? _lng;
  String? _city;
  final String _googleApiKey = Secrets.googleMapsApiKey;

  final List<String> _currencies = ['EUR', 'USD', 'GBP', 'JPY'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _selectedCurrency = data['currency'] ?? 'EUR';
          _lat = data['lat'];
          _lng = data['lng'];
          _city = data['city'];
        });
      }
    }
  }

  // Functie die locatiegegevens zoekt bij GPS-coördinaten via Google Maps
  Future<void> _getLocationDetailsFromCoordinates(double lat, double lng) async {
    String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey';
    
    if (kIsWeb) {
      url = 'https://corsproxy.io/?' + Uri.encodeComponent(url);
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          String formattedAddress = results.isNotEmpty ? results[0]['formatted_address'] : 'Onbekend adres';
          String cityName = 'Onbekend';

          for (var result in results) {
            final addressComponents = result['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('locality')) {
                cityName = component['long_name'];
                break;
              }
            }
            if (cityName != 'Onbekend') break;
          }

          setState(() {
            _lat = lat;
            _lng = lng;
            _city = cityName;
            _addressController.text = formattedAddress;
          });
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locatieservices zijn uitgeschakeld.')),
      );
      return;
    }

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
      await _getLocationDetailsFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      print('Location error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'currency': _selectedCurrency,
            'lat': _lat,
            'lng': _lng,
            'city': _city,
          }, SetOptions(merge: true));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Instellingen opgeslagen!')),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij opslaan: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String mapUrl = "";
    if (_lat != null && _lng != null) {
      // We gebruiken OpenStreetMap via de Static Maps API van Yandex of een andere provider 
      // die geen API key vereist voor simpele kaarten.
      // Dit is een robuuste fallback voor Google Maps 403 fouten.
      mapUrl = "https://static-maps.yandex.ru/1.x/?ll=$_lng,$_lat&z=15&l=map&size=600,300&pt=$_lng,$_lat,pm2rdm";
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Naam',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Vul een naam in' : null,
                          ),
                          const SizedBox(height: 24),
                          const Text('Adresinstellingen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Adres',
                              prefixIcon: const Icon(Icons.location_on),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Huidige locatie ophalen',
                                onPressed: _getCurrentLocation,
                              ),
                            ),
                            maxLines: 2,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          if (_lat != null && _lng != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    mapUrl,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: Colors.grey[200],
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.map_outlined, size: 50, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('Kaart kon niet laden (Check API key)', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Stad: ${_city ?? "Onbekend"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),

                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            decoration: const InputDecoration(
                              labelText: 'Munteenheid',
                              prefixIcon: Icon(Icons.money),
                            ),
                            items: _currencies.map((String currency) {
                              return DropdownMenuItem(value: currency, child: Text(currency));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCurrency = value!),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Instellingen Opslaan'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
