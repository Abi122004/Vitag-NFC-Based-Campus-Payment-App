import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Notification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Get all notifications
  Future<List<Notification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];

    List<Notification> notifications = [];
    for (var json in notificationsJson) {
      try {
        notifications.add(Notification.fromJson(jsonDecode(json)));
      } catch (e) {
        // Skip invalid notifications
      }
    }

    // Sort by timestamp (newest first)
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  // Add a new notification
  Future<void> addNotification(Notification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];

    // Add new notification
    notificationsJson.add(jsonEncode(notification.toJson()));

    // Keep only the 20 most recent notifications
    if (notificationsJson.length > 20) {
      List<Notification> notifications = [];
      for (var json in notificationsJson) {
        try {
          notifications.add(Notification.fromJson(jsonDecode(json)));
        } catch (e) {
          // Skip invalid notifications
        }
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Keep only the 20 most recent
      notifications = notifications.take(20).toList();

      // Convert back to JSON strings
      notificationsJson.clear();
      for (var notification in notifications) {
        notificationsJson.add(jsonEncode(notification.toJson()));
      }
    }

    // Save updated notifications
    await prefs.setStringList('notifications', notificationsJson);
  }

  // Clear all notifications
  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
  }

  // Add a transaction notification
  Future<void> addTransactionNotification({
    required String title,
    required String message,
  }) async {
    final notification = Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
    );

    await addNotification(notification);
  }
}
