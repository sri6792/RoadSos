// lib/services/sms_service.dart

import 'package:url_launcher/url_launcher.dart';

class SMSService {
  static Future<bool> sendSOS({
    required List<String> numbers,
    required String message,
  }) async {
    try {
      final phones = numbers.join(',');

      final Uri uri = Uri.parse(
        'sms:$phones?body=${Uri.encodeComponent(message)}',
      );

      await launchUrl(uri);

      return true;
    } catch (e) {
      return false;
    }
  }
}