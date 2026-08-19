import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Platform service encapsulating Speech-to-Text and microphone permissions.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;
  bool get isInitialized => _isInitialized;

  Future<bool> hasPermission() async {
    try {
      if (kIsWeb) {
        developer.log('[VOICE] Permission status: granted (Web)', name: 'VOICE');
        return true;
      }
      final status = await Permission.microphone.status;
      developer.log('[VOICE] Permission status: ${status.name}', name: 'VOICE');
      return status.isGranted;
    } catch (e, stack) {
      developer.log('[VOICE] Permission status check exception: $e\n$stack', name: 'VOICE');
      return true;
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) return true;
      final status = await Permission.microphone.request();
      developer.log('[VOICE] Permission status after request: ${status.name}', name: 'VOICE');
      return status.isGranted;
    } catch (e, stack) {
      developer.log('[VOICE] Permission request exception: $e\n$stack', name: 'VOICE');
      return true;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      developer.log('[VOICE] Speech initialized: true (already initialized)', name: 'VOICE');
      return true;
    }
    try {
      _isInitialized = await _speech.initialize(
        onError: (errorNotification) {
          developer.log('[VOICE] onError: ${errorNotification.errorMsg}', name: 'VOICE');
        },
        onStatus: (status) {
          developer.log('[VOICE] onStatus: $status', name: 'VOICE');
        },
      );
      developer.log('[VOICE] Speech initialized: $_isInitialized', name: 'VOICE');
      return _isInitialized;
    } catch (e, stack) {
      developer.log('[VOICE] Speech init exception: $e\n$stack', name: 'VOICE');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> startListening({
    required Function(String recognizedText) onResult,
    required Function(String error) onError,
    required VoidCallback onDone,
  }) async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          onError('Microphone permission denied. Please enable it in device Settings.');
          return;
        }
      }

      final initialized = await initialize();
      if (!initialized) {
        onError('Voice recognition unavailable on this device/browser.');
        return;
      }

      developer.log('[VOICE] Listening started', name: 'VOICE');
      await _speech.listen(
        onResult: (result) {
          developer.log('[VOICE] Recognized text: "${result.recognizedWords}"', name: 'VOICE');
          onResult(result.recognizedWords);
          if (result.finalResult) {
            developer.log('[VOICE] Listening stopped', name: 'VOICE');
            onDone();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.search,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e, stack) {
      developer.log('[VOICE] Caught exception in startListening: $e\n$stack', name: 'VOICE');
      onError('Unable to start speech recognition: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        developer.log('[VOICE] Listening stopped', name: 'VOICE');
        await _speech.stop();
      }
    } catch (e, stack) {
      developer.log('[VOICE] Caught exception in stopListening: $e\n$stack', name: 'VOICE');
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        developer.log('[VOICE] Listening stopped (canceled)', name: 'VOICE');
        await _speech.cancel();
      }
    } catch (e, stack) {
      developer.log('[VOICE] Caught exception in cancelListening: $e\n$stack', name: 'VOICE');
    }
  }
}
