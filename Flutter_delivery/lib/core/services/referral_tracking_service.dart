import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralTrackingService {
  static const String _referralKey = 'referral_code';

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_referralKey)) {
        return; // Already have a code
      }

      String? code;

      // Check Install Referrer (Android only)
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final referrerDetails = await AndroidPlayInstallReferrer.installReferrer;
          final referrerString = referrerDetails.installReferrer;
          
          if (referrerString != null && referrerString.isNotEmpty) {
            // The referrer string is typically URL-encoded parameters like:
            // "utm_source=google-play&utm_medium=organic"
            // or "referrer=6a64baafc8248e1b5dc44e0f"
            final uri = Uri.parse('http://dummy.com?$referrerString');
            code = uri.queryParameters['ref'] ?? uri.queryParameters['referrer'];
            
            // If we couldn't parse it as query param, and it doesn't look like standard utm tags,
            // it might be the raw code itself.
            if (code == null && !referrerString.contains('utm_')) {
              code = referrerString; 
            }
          }
        } catch (e) {
          debugPrint('Failed to get install referrer: $e');
        }
      }

      if (code != null && code.isNotEmpty) {
        await prefs.setString(_referralKey, code);
      }
    } catch (e) {
      debugPrint('Error initializing ReferralTrackingService: $e');
    }
  }

  static Future<String?> getReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_referralKey);
  }

  static Future<void> saveReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_referralKey, code);
  }

  static Future<void> clearReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_referralKey);
  }
}
