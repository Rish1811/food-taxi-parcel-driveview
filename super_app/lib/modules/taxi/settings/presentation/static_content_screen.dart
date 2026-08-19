import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';

class StaticContentScreen extends StatelessWidget {
  final String title;
  final String body;

  const StaticContentScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
      ),
    );
  }
}

const privacyPolicyBody = '''
Your privacy matters to us. This app collects location data to enable pickup and drop-off, ride matching and live tracking; contact details for account creation and support; and payment metadata to process fares and wallet top-ups through our payment partners.

We do not sell your personal data. Information is shared only with drivers assigned to your ride (name, phone, live location during the trip) and with payment processors required to complete transactions.

You can request a copy of your data or ask us to delete your account at any time from Profile > Delete account. For questions about this policy, please raise a support ticket from the Help & support section.
''';

const termsBody = '''
By using this app you agree to book rides responsibly, provide accurate pickup and drop information, and treat drivers with respect. Fares are calculated based on distance, time and applicable surge pricing and are shown before you confirm a booking.

Cancellations made after a driver has been assigned may incur a cancellation fee. Wallet balances are non-transferable and non-refundable except where required by law. We reserve the right to suspend accounts found violating these terms, including fraudulent payment activity or abuse toward drivers.

These terms may be updated periodically; continued use of the app after changes constitutes acceptance of the revised terms.
''';
