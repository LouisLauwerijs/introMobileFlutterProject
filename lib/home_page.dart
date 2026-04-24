import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_card.dart';
import 'add_device_page.dart';
import 'device_details_page.dart';

/// De 'HomePage' is het startscherm van de app.
/// Hier zie je de lijst met alle apparaten die mensen te leen aanbieden.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DeviceService _deviceService = DeviceService(); // Toegang tot de database functies
  String? _selectedCategory; // Welke categorie heeft de gebruiker aangeklikt?
  String _selectedCity = ''; // Op welke stad wordt er gefilterd?
  final TextEditingController _cityController = TextEditingController();

  // De lijst met alle opties voor het filteren
  final List<String> _categories = [
    'Alle',
    'Gereedschap',
    'Tuin',
    'Keuken',
    'Elektronica',
    'Vervoer',
    'Overig',
  ];

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peerby - Deel Toestellen'),
        actions: [
          // Uitlog-knop bovenin de balk
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Het 'Filter' gedeelte bovenaan het scherm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // De horizontale rij met categorie-knopjes (Chips)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: (_selectedCategory == category) ||
                              (_selectedCategory == null && category == 'Alle'),
                          onSelected: (selected) {
                            setState(() {
                              // Als je op een categorie tikt, verversen we de lijst
                              _selectedCategory = category == 'Alle' ? null : category;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Het tekstveld om op stad te filteren
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'Filter op stad',
                    prefixIcon: const Icon(Icons.location_city),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        // Knopje om het tekstveld leeg te maken
                        _cityController.clear();
                        setState(() {
                          _selectedCity = '';
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      // Pas de lijst aan zodra je op 'Enter' klikt
                      _selectedCity = value.trim();
                    });
                  },
                ),
              ],
            ),
          ),
          // De lijst met apparaten (vult de rest van het scherm)
          Expanded(
            child: StreamBuilder<List<Device>>(
              // We 'luisteren' naar de database met de gekozen filters
              stream: _deviceService.getDevices(
                category: _selectedCategory,
                city: _selectedCity.isNotEmpty ? _selectedCity : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fout bij laden: ${snapshot.error}'));
                }

                // Wieltje laten draaien als we nog aan het wachten zijn op de database
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final devices = snapshot.data ?? [];

                // Melding als er geen apparaten zijn die aan de filters voldoen
                if (devices.isEmpty) {
                  return const Center(child: Text('Geen toestellen gevonden.'));
                }

                // De daadwerkelijke lijst met 'Kaartjes' van apparaten
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return DeviceCard(
                      device: device,
                      onTap: () {
                        // Tikken op een kaartje opent de details van dat apparaat
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
      // De grote '+' knop rechtsonder om zelf een apparaat toe te voegen
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDevicePage()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
