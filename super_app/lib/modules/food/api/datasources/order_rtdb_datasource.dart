import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:superapp_user/core/config/app_constants.dart';
import 'package:superapp_user/modules/food/data/models/active_order_rtdb_model.dart';

void _rtdbLog(String message) {
  if (kDebugMode) debugPrint('[RTDB] $message');
}

/// Firebase Realtime Database Data Source for live order tracking.
/// Reads directly from `active_orders/{orderMongoId}` node.
class OrderRtdbDataSource {
  static final String _rtdbUrl = AppConstants.firebaseDatabaseUrl;

  FirebaseDatabase? _database;

  Future<FirebaseDatabase> _getDatabase() async {
    if (_database != null) return _database!;
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        _rtdbLog('Firebase.initializeApp() failed: $e');
      }
    }
    try {
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      );
    } catch (e) {
      _rtdbLog('instanceFor($_rtdbUrl) failed, falling back to default instance: $e');
      _database = FirebaseDatabase.instance;
    }
    return _database!;
  }

  /// Listens to single RTDB stream on node `active_orders/{orderMongoId}`.
  Stream<ActiveOrderRtdbModel?> watchActiveOrder(String orderMongoId) async* {
    if (orderMongoId.trim().isEmpty) {
      _rtdbLog('watchActiveOrder called with empty orderMongoId — not subscribing');
      yield null;
      return;
    }

    final path = 'active_orders/$orderMongoId';
    _rtdbLog('Subscribing to $path');

    try {
      final db = await _getDatabase();
      final ref = db.ref(path);

      await for (final event in ref.onValue) {
        final snapshot = event.snapshot;
        if (!snapshot.exists || snapshot.value == null) {
          _rtdbLog('$path — snapshot empty (no node yet, or order not picked up)');
          yield null;
          continue;
        }

        final data = snapshot.value;
        if (data is Map) {
          final model = ActiveOrderRtdbModel.fromMap(data);
          _rtdbLog(
            '$path — snapshot received: '
            'polyline=${model.polyline == null ? 'null' : '${model.polyline!.length} chars'}, '
            'lat=${model.lat}, lng=${model.lng}, '
            'restaurant=(${model.restaurantLat}, ${model.restaurantLng}), '
            'customer=(${model.customerLat}, ${model.customerLng}), '
            'status=${model.status}',
          );
          yield model;
        } else {
          _rtdbLog('$path — snapshot value is not a Map: ${data.runtimeType}');
          yield null;
        }
      }
    } catch (e, st) {
      _rtdbLog('$path — subscription error: $e\n$st');
      yield null;
    }
  }
}
