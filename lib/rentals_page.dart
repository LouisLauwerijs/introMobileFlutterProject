import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'device_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalsPage extends StatelessWidget {
  const RentalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Huren'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: deviceService.getUserRentals(),
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
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Je hebt nog niets gehuurd.',
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
              final hasReview = rental['hasReview'] ?? false;

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
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '€${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Van: ${DateFormat('dd/MM/yyyy').format(startDate)}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Tot: ${DateFormat('dd/MM/yyyy').format(endDate)}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status: Bevestigd',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!hasReview)
                            ElevatedButton(
                              onPressed: () => _showReviewDialog(context, rental),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Schrijf Recensie'),
                            )
                          else
                            const Text(
                              'Beoordeeld',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                        ],
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

  void _showReviewDialog(BuildContext context, Map<String, dynamic> rental) {
    int selectedRating = 5;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Recensie schrijven'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Hoe was je ervaring met dit apparaat?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Deel je ervaring...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await DeviceService().addReview(
                        rentalId: rental['id'],
                        deviceId: rental['deviceId'],
                        rating: selectedRating,
                        comment: commentController.text,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bedankt voor je recensie!')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fout bij plaatsen recensie: $e')),
                      );
                    }
                  },
                  child: const Text('Verzenden'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
