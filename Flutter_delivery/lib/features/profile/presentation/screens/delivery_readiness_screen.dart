import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/device_readiness_service.dart';

/// Walks the rider through the device settings that decide whether they actually
/// receive orders.
///
/// Shown from the profile, and offered once when going online with something
/// outstanding. Re-checks on resume, because every fix here happens in the system
/// settings app and the rider comes back expecting the tick to have moved.
class DeliveryReadinessScreen extends StatefulWidget {
  const DeliveryReadinessScreen({super.key});

  @override
  State<DeliveryReadinessScreen> createState() => _DeliveryReadinessScreenState();
}

class _DeliveryReadinessScreenState extends State<DeliveryReadinessScreen>
    with WidgetsBindingObserver {
  List<ReadinessCheck>? _checks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final checks = await DeviceReadinessService.evaluate();
    if (mounted) setState(() => _checks = checks);
  }

  @override
  Widget build(BuildContext context) {
    final checks = _checks;

    return Scaffold(
      appBar: AppBar(title: const Text('Order delivery settings')),
      body: checks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Your phone can stop the app running in the background, which '
                    'means you stop getting orders without any warning. Turn these '
                    'on once and you are set.',
                    style: TextStyle(fontSize: 13.sp, height: 1.4),
                  ),
                ),
                SizedBox(height: 16.h),
                ...checks.map(_buildCheck),
              ],
            ),
    );
  }

  Widget _buildCheck(ReadinessCheck check) {
    // Autostart cannot be read back on any ROM that has it, so it shows as a
    // neutral step to confirm rather than a red cross the rider can never clear.
    final unknown = check.id == 'autostart';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unknown
                  ? Icons.help_outline_rounded
                  : check.satisfied
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
              color: unknown
                  ? Colors.blueGrey
                  : check.satisfied
                      ? Colors.green
                      : (check.critical ? Colors.red : Colors.orange),
              size: 22.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    check.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      height: 1.35,
                    ),
                  ),
                  if (unknown || !check.satisfied) ...[
                    SizedBox(height: 10.h),
                    OutlinedButton(
                      onPressed: () async {
                        await DeviceReadinessService.fix(check.id);
                        await _refresh();
                      },
                      child: Text(unknown ? 'Open settings' : 'Fix now'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
