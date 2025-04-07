import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseInitializer {
  static Future<void> initialize() async {
    final pushNotify = Platform.environment['PUSH_NOTIFY'] == 'true';
    if (pushNotify) {
      await Firebase.initializeApp();
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request permissions if needed (for iOS)
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await messaging.requestPermission();
      }

      String? token = await messaging.getToken();
      print('🔔 FCM Token: $token');
    } else {
      print('🚫 Push Notification not enabled');
    }
  }
}
