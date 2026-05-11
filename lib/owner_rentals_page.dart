import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'device_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerRentalsPage extends StatelessWidget {
  const OwnerRentalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Verhuurgeschiedenis'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: deviceService.getOwnerRentals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Er is iets fout gegaan: ${snapshot.error}'));
          }

          final rentals = snapshot.data ?? [];

          if (rentals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Je hebt nog niets verhuurd.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rentals.length,
            itemBuilder: (context, index) {
              final rental = rentals[index];
              final startDate = (rental['startDate'] as Timestamp).toDate();
              final endDate = (rental['endDate'] as Timestamp).toDate();
              final totalPrice = rental['totalPrice'] as double;
              final deviceName = rental['deviceName'] ?? 'Onbekend apparaat';
              final deviceId = rental['deviceId'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              deviceName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '€${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Huurperiode: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      const SizedBox(height: 16),
                      const Text(
                        'Ontvangen Recensie:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: deviceService.getDeviceReviews(deviceId),
                        builder: (context, reviewSnapshot) {
                          if (!reviewSnapshot.hasData || reviewSnapshot.data!.isEmpty) {
                            return const Text(
                              'Nog geen recensie ontvangen voor dit apparaat.',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                            );
                          }
                          
                          // Find the review for this specific rental
                          final reviews = reviewSnapshot.data!;
                          final rentalReview = reviews.firstWhere(
                            (r) => r['rentalId'] == rental['id'],
                            orElse: () => {},
                          );

                          if (rentalReview.isEmpty) {
                            return const Text(
                              'Huurder heeft nog geen recensie geschreven voor deze huur.',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < (rentalReview['rating'] as int)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.orange,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"${rentalReview['comment']}"',
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                              Text(
                                '- Door ${rentalReview['renterName']}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
