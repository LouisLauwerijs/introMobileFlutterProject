import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_card.dart';
import 'device_details_page.dart';
import 'settings_page.dart';
import 'rentals_page.dart';
import 'owner_rentals_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Profiel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final userData = snapshot.data?.data() as Map<String, dynamic>?;

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          child: Icon(Icons.person, size: 30),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userData?['name'] ?? 'Geen naam',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user?.email ?? 'Geen e-mail',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            // Toon gemiddelde score
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: deviceService.getOwnerReviews(user?.uid ?? ''),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Text(
                                    'Nog geen beoordelingen',
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  );
                                }

                                final reviews = snapshot.data!;
                                final average = reviews.fold<double>(0, (sum, r) => sum + (r['rating'] as int)) / reviews.length;

                                return Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${average.toStringAsFixed(1)} (${reviews.length} reviews)',
                                      style: const TextStyle(
                                        fontSize: 14,
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
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () async => await authService.signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HuurgeschiedenisPage()),
                              );
                            },
                            icon: const Icon(Icons.history),
                            label: const Text('Huurgeschiedenis'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OwnerRentalsPage()),
                              );
                            },
                            icon: const Icon(Icons.assignment),
                            label: const Text('Mijn Verhuur'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                    ),
                    );
                    },
                    ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mijn aangeboden toestellen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Device>>(
              stream: deviceService.getDevices(),
              builder: (context, deviceSnapshot) {
                if (deviceSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter de lijst zodat we alleen de EIGEN EN BESCHIKBARE apparaten zien
                final myDevices = deviceSnapshot.data?.where((d) => d.ownerId == user?.uid && d.isAvailable).toList() ?? [];

                if (myDevices.isEmpty) {
                  return const Center(child: Text('Je hebt momenteel geen actieve toestellen.'));
                }

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: deviceService.getOwnerRentals(),
                  builder: (context, rentalSnapshot) {
                    final ownerRentals = rentalSnapshot.data ?? [];
                    
                    // Sorteren: Eerst beschikbare toestellen, dan verhuurde op startdatum
                    myDevices.sort((a, b) {
                      if (a.isAvailable && !b.isAvailable) return -1;
                      if (!a.isAvailable && b.isAvailable) return 1;
                      
                      if (!a.isAvailable && !b.isAvailable) {
                        final aRental = ownerRentals.firstWhere((r) => r['deviceId'] == a.id, orElse: () => {});
                        final bRental = ownerRentals.firstWhere((r) => r['deviceId'] == b.id, orElse: () => {});
                        
                        final aStart = (aRental['startDate'] as Timestamp?)?.toDate();
                        final bStart = (bRental['startDate'] as Timestamp?)?.toDate();
                        
                        if (aStart == null) return 1;
                        if (bStart == null) return -1;
                        return aStart.compareTo(bStart);
                      }
                      return 0;
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: myDevices.length,
                      itemBuilder: (context, index) {
                        final device = myDevices[index];
                        final rental = ownerRentals.firstWhere(
                          (r) => r['deviceId'] == device.id, 
                          orElse: () => {},
                        );
                        
                        DateTime? startDate = (rental['startDate'] as Timestamp?)?.toDate();
                        DateTime? endDate = (rental['endDate'] as Timestamp?)?.toDate();
                        String? rName = rental['renterName'];
                        String? rId = rental['renterId'];

                        return DeviceCard(
                          device: device,
                          rentalStartDate: startDate,
                          rentalEndDate: endDate,
                          renterName: rName,
                          renterId: rId,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
