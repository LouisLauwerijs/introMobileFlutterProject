import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_model.dart';

/// Dit bestand maakt de 'Kaart' (Card) die je ziet in de lijst op de startpagina.
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: _buildImage(device.photoUrl),
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
                  Text(
                    device.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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

