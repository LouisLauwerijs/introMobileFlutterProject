import 'dart:convert';
import 'package:flutter/material.dart';
import 'device_model.dart';
import 'device_service.dart';

/// Dit is de detailpagina van een apparaat. Hier zie je alle informatie uitgebreid.
/// De pagina wordt geopend wanneer je in de lijst op een apparaat tikt.
class DeviceDetailsPage extends StatelessWidget {
  final Device device;

  const DeviceDetailsPage({super.key, required this.device});

  // Functie die de foto op het scherm zet (werkt hetzelfde als in de Card)
  Widget _buildImage(String photoUrl) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        return Image.memory(
          base64Decode(base64String),
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
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
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(device.category)),
      body: SingleChildScrollView( // Zorgt ervoor dat je naar beneden kunt scrollen als de tekst lang is
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grote foto bovenaan
            _buildImage(device.photoUrl),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prijs en Categorie
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        device.category,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '€${device.price.toStringAsFixed(2)} / dag',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Naam van het apparaat
                  Text(
                    device.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Beschrijving
                  Text(
                    device.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Locatie informatie
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        device.city,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Beschikbaarheid laten zien
                  const Text(
                    'Beschikbaarheid',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        device.isAvailable ? Icons.check_circle : Icons.cancel,
                        color: device.isAvailable ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.isAvailable ? 'Nu beschikbaar' : 'Niet beschikbaar',
                        style: TextStyle(
                          color: device.isAvailable ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // De grote knop onderaan om het apparaat te huren
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: device.isAvailable
                          ? () {
                              // Wat er gebeurt als je op huren klikt
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Huurverzoek verstuurd!')),
                              );
                            }
                          : null, // Knop is grijs als het apparaat niet beschikbaar is
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Toestel Huren'),
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
