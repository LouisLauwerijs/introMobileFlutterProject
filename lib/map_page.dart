import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_details_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DeviceService _deviceService = DeviceService();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toestellen in de buurt'),
      ),
      body: StreamBuilder<List<Device>>(
        stream: _deviceService.getDevices(onlyAvailable: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _currentPosition == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = snapshot.data ?? [];
          
          return MapView(
            devices: devices,
            currentPosition: _currentPosition,
          );
        },
      ),
    );
  }
}

class MapView extends StatefulWidget {
  final List<Device> devices;
  final Position? currentPosition;

  const MapView({
    super.key,
    required this.devices,
    this.currentPosition,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dit zorgt ervoor dat de markers DIRECT worden bijgewerkt als de lijst met devices verandert
    if (widget.devices != oldWidget.devices) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = widget.devices.map((device) {
        return Marker(
          markerId: MarkerId(device.id),
          position: LatLng(device.location.latitude, device.location.longitude),
          onTap: () => _showDevicePreview(device),
        );
      }).toSet();
    });
  }

  void _showDevicePreview(Device device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: device.photoUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(device.photoUrl.split(',')[1]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          device.photoUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported, size: 80),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '€${device.price.toStringAsFixed(2)} per dag',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(device.city, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeviceDetailsPage(device: device)),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(
        target: widget.currentPosition != null
            ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
            : const LatLng(51.2194, 4.4025),
        zoom: 13,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: _markers,
      mapToolbarEnabled: false,
    );
  }
}
