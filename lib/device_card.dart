import 'dart:convert';
import 'package:flutter/material.dart';
import 'device_model.dart';

/// Dit bestand maakt de 'Kaart' (Card) die je ziet in de lijst op de startpagina.
/// Het bevat de foto, naam, prijs en categorie van een enkel apparaat.
class DeviceCard extends StatelessWidget {
  final Device device;        // Het specifieke apparaat dat op deze kaart getoond wordt
  final VoidCallback onTap;   // Wat er moet gebeuren als je op de kaart tikt (meestal: details openen)

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  // Functie die slim beslist hoe de foto getoond moet worden
  Widget _buildImage(String photoUrl) {
    // Als de tekst begint met 'data:image', is het een foto die we rechtstreeks uit de database laden
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        return Image.memory(
          base64Decode(base64String),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover, // De foto de ruimte mooi laten vullen
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 150), // Als het laden mislukt, toon een icoon
        );
      } catch (e) {
        return const Icon(Icons.broken_image, size: 150);
      }
    } else {
      // Oude foto's of foto's die ergens op het internet staan
      return Image.network(
        photoUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 150),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4, // Geeft een kleine schaduw onder de kaart
      child: InkWell(
        onTap: onTap, // Laat de kaart reageren op tikken
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Het bovenste gedeelte van de kaart: de afbeelding
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: _buildImage(device.photoUrl),
            ),
            // Het onderste gedeelte: de informatie (tekst)
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
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '€${device.price.toStringAsFixed(2)}/dag',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // Voegt '...' toe als de naam te lang is
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        device.ownerName,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
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
