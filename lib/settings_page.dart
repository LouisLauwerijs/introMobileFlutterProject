import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  double? _lat;
  double? _lng;
  String? _city;
  final String _apiKey = Secrets.googleMapsApiKey;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _suppressListener = false; // prevents autocomplete firing when we set text in code

  final List<String> _currencies = ['EUR', 'USD', 'GBP', 'JPY'];

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _loadUserData();
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Autocomplete ────────────────────────────────────────────────────────────

  void _onAddressChanged() {
    if (_suppressListener) return;
    final query = _addressController.text.trim();
    if (query.length >= 3) {
      _fetchSuggestions(query);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&key=$_apiKey'
      '&language=nl',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          if (mounted) {
            setState(() {
              _suggestions = predictions
                  .map((p) => {
                        'placeId': p['place_id'] as String,
                        'description': p['description'] as String,
                      })
                  .toList();
              _showSuggestions = _suggestions.isNotEmpty;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    // Set text without triggering the listener
    _suppressListener = true;
    _addressController.text = suggestion['description'];
    _suppressListener = false;

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });

    await _fetchPlaceDetails(suggestion['placeId']);
  }

  // ─── Place Details (placeId → lat/lng) ──────────────────────────────────────

  Future<void> _fetchPlaceDetails(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry,formatted_address,address_components'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();

          String cityName = 'Onbekend';
          for (var component in result['address_components'] as List) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              cityName = component['long_name'];
              break;
            }
          }

          setState(() {
            _lat = lat;
            _lng = lng;
            _city = cityName;
          });

          _moveMapTo(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  // ─── Reverse Geocode (lat/lng → address) ─────────────────────────────────────

  Future<void> _reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          final formattedAddress = results.isNotEmpty
              ? results[0]['formatted_address'] as String
              : 'Onbekend adres';

          String cityName = 'Onbekend';
          for (var result in results) {
            for (var component in result['address_components'] as List) {
              final types = component['types'] as List;
              if (types.contains('locality')) {
                cityName = component['long_name'];
                break;
              }
            }
            if (cityName != 'Onbekend') break;
          }

          _suppressListener = true;
          setState(() {
            _lat = lat;
            _lng = lng;
            _city = cityName;
            _addressController.text = formattedAddress;
            _suggestions = [];
            _showSuggestions = false;
          });
          _suppressListener = false;

          _moveMapTo(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }

  // ─── Map helpers ─────────────────────────────────────────────────────────────

  void _moveMapTo(double lat, double lng) {
    final position = LatLng(lat, lng);

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locatieservices zijn uitgeschakeld.')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locatiepermissie geweigerd.')),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('GPS error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Firebase ────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;
    final data = doc.data()!;

    _suppressListener = true;
    setState(() {
      _nameController.text = data['name'] ?? '';
      _addressController.text = data['address'] ?? '';
      _selectedCurrency = data['currency'] ?? 'EUR';
      _lat = (data['lat'] as num?)?.toDouble();
      _lng = (data['lng'] as num?)?.toDouble();
      _city = data['city'];
    });
    _suppressListener = false;

    if (_lat != null && _lng != null) {
      _moveMapTo(_lat!, _lng!);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij opslaan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              // Tapping outside dismisses the suggestions dropdown
              onTap: () => setState(() => _showSuggestions = false),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            // ── Name ──────────────────────────────────────────
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Naam',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Vul een naam in' : null,
                            ),

                            const SizedBox(height: 24),
                            const Text(
                              'Adresinstellingen',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // ── Address search ────────────────────────────────
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Adres zoeken',
                                hintText: 'Begin met typen…',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.my_location),
                                  tooltip: 'Huidige locatie gebruiken',
                                  onPressed: _getCurrentLocation,
                                ),
                              ),
                              maxLines: 2,
                            ),

                            // ── Autocomplete dropdown ─────────────────────────
                            if (_showSuggestions && _suggestions.isNotEmpty)
                              Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  children: _suggestions.map((s) {
                                    return ListTile(
                                      leading: const Icon(Icons.location_on,
                                          color: Colors.blue),
                                      title: Text(
                                        s['description'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      onTap: () => _selectSuggestion(s),
                                    );
                                  }).toList(),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // ── Map ───────────────────────────────────────────
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 220,
                                child: _lat != null && _lng != null
                                    ? GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(_lat!, _lng!),
                                          zoom: 15,
                                        ),
                                        markers: _markers,
                                        onMapCreated: (c) => _mapController = c,
                                        myLocationButtonEnabled: false,
                                        zoomControlsEnabled: true,
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.map_outlined,
                                                size: 50, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text(
                                              'Zoek een adres of gebruik\nuw huidige locatie',
                                              style:
                                                  TextStyle(color: Colors.grey),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),

                            if (_city != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Stad: $_city',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
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
            ),
    );
  }
}