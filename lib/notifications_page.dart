import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'device_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceService deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meldingen'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: deviceService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Fout bij laden meldingen: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Geen nieuwe meldingen.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              final String type = item['type'];
              final String msg = item['msg'];
              final Timestamp? sortDate = item['sortDate'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getBgColor(type),
                    child: Icon(_getIcon(type), color: Colors.white),
                  ),
                  title: Text(msg),
                  subtitle: sortDate != null 
                    ? Text(DateFormat('dd/MM HH:mm').format(sortDate.toDate()))
                    : null,
                  trailing: _buildTrailing(context, deviceService, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context, DeviceService service, Map<String, dynamic> item) {
    final String type = item['type'];

    if (type == 'incoming_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => _handleRequest(context, service, item, true),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _handleRequest(context, service, item, false),
          ),
        ],
      );
    }

    if (type == 'message' || type == 'request_response') {
      return IconButton(
        icon: const Icon(Icons.chat, color: Colors.blue),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                rentalId: item['rentalId'],
                otherUserId: item['type'] == 'message' 
                  ? (FirebaseAuth.instance.currentUser!.uid == item['receiverId'] ? (item['senderId'] ?? 'TODO') : item['receiverId'])
                  : (FirebaseAuth.instance.currentUser!.uid == item['ownerId'] ? item['renterId'] : item['ownerId']),
                deviceName: item['deviceName'] ?? 'Toestel',
              ),
            ),
          );
        },
      );
    }

    return null;
  }

  Color _getBgColor(String type) {
    switch (type) {
      case 'incoming_request': return Colors.blue;
      case 'request_response': return Colors.orange;
      case 'date_alert': return Colors.purple;
      case 'message': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'incoming_request': return Icons.person_add;
      case 'request_response': return Icons.reply;
      case 'date_alert': return Icons.calendar_today;
      case 'message': return Icons.chat;
      default: return Icons.notifications;
    }
  }

  void _handleRequest(BuildContext context, DeviceService service, Map<String, dynamic> item, bool accept) async {
    try {
      await service.handleRentalRequest(item['id'], item['deviceId'], accept);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Aanvraag geaccepteerd!' : 'Aanvraag geweigerd.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij afhandelen: $e')),
        );
      }
    }
  }
}
