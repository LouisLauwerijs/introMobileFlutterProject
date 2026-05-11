import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'secrets.dart';
import 'device_service.dart';

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();

  String _category = 'Gereedschap';
  XFile? _imageFile;
  bool _isLoading = false;

  // Locatiegegevens
  double? _lat;
  double? _lng;
  String _city = '';
  String _locationName = '';

  // Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _suppressListener = false;

  // Kaart
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  final String _apiKey = Secrets.googleMapsApiKey;

  final List<String> _categories = [
    'Gereedschap', 'Tuin', 'Keuken', 'Elektronica', 'Vervoer', 'Overig',
  ];

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Autocomplete ─────────────────────────────────────────────────────────

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
    if (kIsWeb) return; // Werkt niet op web door CORS

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
        if (data['status'] == 'OK' && mounted) {
          final predictions = data['predictions'] as List;
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
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    _suppressListener = true;
    _addressController.text = suggestion['description'];
    _suppressListener = false;

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });

    await _fetchPlaceDetails(suggestion['placeId']);
  }

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
            _locationName = result['formatted_address'];
          });

          _moveMapTo(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locatieservices zijn uitgeschakeld.')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locatiepermissie geweigerd.')),
        );
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
            _locationName = formattedAddress;
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

  // ─── Kaart ────────────────────────────────────────────────────────────────

  void _moveMapTo(double lat, double lng) {
    final position = LatLng(lat, lng);
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('device_location'),
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

  // ─── Foto ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  // ─── Opslaan ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kies een foto voor het toestel.')),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kies een locatie via het zoekveld of GPS.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DeviceService().addDevice(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _category,
        imageFile: _imageFile!,
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        location: GeoPoint(_lat!, _lng!),
        city: _city,
        locationName: _locationName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij opslaan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toestel Verhuren')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => setState(() => _showSuggestions = false),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // ── Naam ──────────────────────────────────────────────
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Naam van het toestel',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vul een naam in' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Beschrijving ───────────────────────────────────────
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Beschrijving',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => (v == null || v.isEmpty) ? 'Vul een beschrijving in' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Categorie ──────────────────────────────────────────
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categorie',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                      const SizedBox(height: 16),

                      // ── Prijs ──────────────────────────────────────────────
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Prijs per dag (€)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vul een prijs in' : null,
                      ),
                      const SizedBox(height: 20),

                      // ── Foto ───────────────────────────────────────────────
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
                                      ? Image.network(_imageFile!.path, fit: BoxFit.contain)
                                      : Image.file(io.File(_imageFile!.path), fit: BoxFit.contain),
                                ),
                                TextButton(
                                  onPressed: _pickImage,
                                  child: const Text('Wijzig Foto'),
                                ),
                              ],
                            ),
                      const SizedBox(height: 20),

                      // ── Locatie sectie ─────────────────────────────────────
                      const Text(
                        'Locatie',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Adres zoekbalk met GPS knop
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Adres zoeken',
                          hintText: 'Begin met typen...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location),
                            tooltip: 'Huidige locatie gebruiken',
                            onPressed: _getCurrentLocation,
                          ),
                        ),
                      ),

                      // Autocomplete dropdown
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            children: _suggestions.map((s) {
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.blue),
                                title: Text(s['description'], style: const TextStyle(fontSize: 13)),
                                onTap: () => _selectSuggestion(s),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Kaartpreview (verschijnt zodra locatie is gekozen)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 200,
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_outlined, size: 50, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Zoek een adres of gebruik GPS\nom de locatie in te stellen',
                                        style: TextStyle(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),

                      if (_city.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Stad: $_city',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 32),

                      // ── Opslaan ────────────────────────────────────────────
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
            ),
    );
  }
}