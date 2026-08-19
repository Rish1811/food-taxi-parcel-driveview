import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';

class NoNetworkOverlay extends ConsumerStatefulWidget {
  const NoNetworkOverlay({super.key});

  @override
  ConsumerState<NoNetworkOverlay> createState() => _NoNetworkOverlayState();
}

class _NoNetworkOverlayState extends ConsumerState<NoNetworkOverlay> {
  bool _dismissedTemporarily = false;
  bool _isChecking = false;

  Future<void> _handleTryAgain() async {
    setState(() => _isChecking = true);
    await Connectivity().checkConnectivity();
    try {
      await ref.read(ordersControllerProvider.notifier).refreshCurrent();
      await ref.read(ordersControllerProvider.notifier).refreshAvailable();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedTemporarily) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Soft background blur & dim
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            
            // Center Dialog Card
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Wifi Illustration Graphic
                      _buildIllustration(),
                      
                      const SizedBox(height: 20),
                      
                      // Title: No Internet Connection
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'No Internet ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF04438),
                              ),
                            ),
                            TextSpan(
                              text: 'Connection',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Red Accent Line/Dash
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF04438),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 4,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF04438),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Message Text
                      const Text(
                        'It looks like you are offline.\nPlease check your Wi-Fi or mobile data\nand try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Try Again Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _handleTryAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF04438),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.wifi_off_rounded, size: 20, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Try Again',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Work Offline Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _dismissedTemporarily = true);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.airplanemode_active_rounded, size: 20, color: Colors.black54),
                              SizedBox(width: 8),
                              Text(
                                'Work Offline',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 180,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft pink/peach circle
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF0EB),
            ),
          ),
          
          // Soft cloud shapes on sides
          Positioned(
            left: 10,
            bottom: 30,
            child: Container(
              width: 45,
              height: 25,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3DC).withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          Positioned(
            right: 15,
            top: 35,
            child: Container(
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3DC).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Sparkle accents
          const Positioned(
            left: 28,
            top: 25,
            child: Icon(Icons.close_rounded, size: 10, color: Color(0xFFFFA07A)),
          ),
          const Positioned(
            right: 35,
            bottom: 25,
            child: Icon(Icons.close_rounded, size: 10, color: Color(0xFFFFA07A)),
          ),
          const Positioned(
            left: 50,
            top: 15,
            child: Icon(Icons.star_rate_rounded, size: 12, color: Color(0xFFFFA07A)),
          ),
          
          // Central White Circle with Wifi-Off icon
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFF0EB), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF04438).withOpacity(0.12),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.wifi_off_rounded,
                size: 38,
                color: Color(0xFFF04438),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
