import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_card.dart';
import 'device_details_page.dart';

class UserDetailPage extends StatelessWidget {
  final String userId;
  final String userName;

  const UserDetailPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Profiel van $userName'),
      ),
      body: Column(
        children: [
          // Header met naam en rating
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: deviceService.getOwnerReviews(userId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text(
                            'Nog geen beoordelingen',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          );
                        }

                        final reviews = snapshot.data!;
                        final average = reviews.fold<double>(0, (sum, r) => sum + (r['rating'] as int)) / reviews.length;

                        return Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${average.toStringAsFixed(1)} (${reviews.length} reviews)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Toestellen van deze verhuurder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Lijst met toestellen van deze gebruiker
          Expanded(
            child: StreamBuilder<List<Device>>(
              stream: deviceService.getDevices(onlyAvailable: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userDevices = snapshot.data?.where((d) => d.ownerId == userId).toList() ?? [];

                if (userDevices.isEmpty) {
                  return const Center(child: Text('Geen actieve toestellen gevonden.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: userDevices.length,
                  itemBuilder: (context, index) {
                    final device = userDevices[index];
                    return DeviceCard(
                      device: device,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviceDetailsPage(device: device),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
