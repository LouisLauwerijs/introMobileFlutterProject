import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_model.dart';
import 'device_service.dart';
import 'package:intl/intl.dart';

/// Dit bestand maakt de 'Kaart' (Card) die je ziet in de lijst op de startpagina of profiel.
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final DateTime? rentalStartDate;
  final DateTime? rentalEndDate;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.rentalStartDate,
    this.rentalEndDate,
  });

  // Functie om de naam van de verhuurder op te halen uit Firestore
  Future<String> _getOwnerName(String ownerId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      return (doc.data() as Map<String, dynamic>?)?['name'] ?? 'Onbekende verhuurder';
    } catch (e) {
      return 'Laden...';
    }
  }

  Widget _buildImage(String photoUrl) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        return Image.memory(
          base64Decode(base64String),
          height: 150,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 150),
        );
      } catch (e) {
        return const Icon(Icons.broken_image, size: 150);
      }
    } else {
      return Image.network(
        photoUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 150),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: _buildImage(device.photoUrl),
                ),
                if (!device.isAvailable)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NIET BESCHIKBAAR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        device.category,
                        style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '€${device.price.toStringAsFixed(2)}/dag',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: deviceService.getDeviceReviews(device.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final reviews = snapshot.data!;
                          double avgRating = reviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / reviews.length;
                          return Row(
                            children: [
                              const Icon(Icons.star, color: Colors.orange, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                avgRating.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                ' (${reviews.length})',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rentalStartDate != null && rentalEndDate != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Verhuurd: ${DateFormat('dd/MM').format(rentalStartDate!)} t/m ${DateFormat('dd/MM').format(rentalEndDate!)}',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      FutureBuilder<String>(
                        future: _getOwnerName(device.ownerId),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Laden...',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        device.city,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
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

