import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_model.dart';
import 'device_service.dart';
import 'package:intl/intl.dart';

/// Dit is de detailpagina van een apparaat. Hier zie je alle informatie uitgebreid.
/// De pagina wordt geopend wanneer je in de lijst op een apparaat tikt.
class DeviceDetailsPage extends StatefulWidget {
  final Device device;

  const DeviceDetailsPage({super.key, required this.device});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  DateTimeRange? _selectedDateRange;

  // Functie die de foto op het scherm zet
  Widget _buildImage(String photoUrl) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        return Image.memory(
          base64Decode(base64String),
          height: 300,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 300),
        );
      } catch (e) {
        return const Icon(Icons.broken_image, size: 300);
      }
    } else {
      return Image.network(
        photoUrl,
        height: 300,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 300),
      );
    }
  }

  // Functie om de bevestigingsdialoog te tonen voor het verwijderen
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Toestel Verwijderen'),
          content: const Text('Weet je zeker dat je dit toestel wilt verwijderen uit de lijst?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuleren'),
            ),
            TextButton(
              onPressed: () async {
                await DeviceService().deleteDevice(widget.device.id);
                if (context.mounted) {
                  Navigator.pop(context); // Sluit dialoog
                  Navigator.pop(context); // Terug naar home
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Toestel succesvol verwijderd')),
                  );
                }
              },
              child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Functie om de naam van de verhuurder op te halen uit Firestore
  Future<String> _getOwnerName(String ownerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      final data = doc.data();
      return data?['name'] ?? 'Onbekende verhuurder';
    } catch (e) {
      return 'Laden...';
    }
  }

  // Functie om een datumperiode te kiezen
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  double _calculateTotalPrice() {
    if (_selectedDateRange == null) return 0.0;
    final days = _selectedDateRange!.duration.inDays + 1; // Inclusief einddag
    return days * widget.device.price;
  }

  Future<void> _handleRental() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kies eerst een huurperiode')),
      );
      return;
    }

    try {
      await DeviceService().rentDevice(
        deviceId: widget.device.id,
        deviceName: widget.device.name,
        startDate: _selectedDateRange!.start,
        endDate: _selectedDateRange!.end,
        totalPrice: _calculateTotalPrice(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Huurverzoek succesvol verstuurd!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij huren: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner = currentUser != null && currentUser.uid == widget.device.ownerId;
    final totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.category),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(widget.device.photoUrl),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.device.category,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '€${widget.device.price.toStringAsFixed(2)} / dag',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 8),
                      FutureBuilder<String>(
                        future: _getOwnerName(widget.device.ownerId),
                        builder: (context, snapshot) {
                          return Text(
                            'Aangeboden door: ${snapshot.data ?? 'Laden...'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.device.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.device.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        widget.device.city,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Beschikbaarheid',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        widget.device.isAvailable ? Icons.check_circle : Icons.cancel,
                        color: widget.device.isAvailable ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.device.isAvailable ? 'Nu beschikbaar' : 'Niet beschikbaar',
                        style: TextStyle(
                          color: widget.device.isAvailable ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!isOwner && widget.device.isAvailable) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Huurperiode selecteren',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.blue),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDateRange == null
                                  ? 'Kies begin- en einddatum'
                                  : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Totale prijs:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '€${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isOwner
                          ? () => _showDeleteConfirmation(context)
                          : (widget.device.isAvailable ? _handleRental : null),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isOwner ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isOwner ? 'Toestel Verwijderen' : 'Toestel Huren'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
