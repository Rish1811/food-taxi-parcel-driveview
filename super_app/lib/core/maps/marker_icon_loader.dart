import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Turns backend-supplied vehicle art into map markers.
///
/// The catalog stores `map_icon` as a base64 data URI (and occasionally a plain
/// URL), so both forms are handled. Decoding happens once per source and is
/// cached for the process lifetime — the images are hundreds of KB each and
/// re-decoding them on every camera move would stutter the map.
class MarkerIconLoader {
  MarkerIconLoader._();

  /// Fixed width so a marker looks identical on every device instead of
  /// scaling with whatever resolution the admin happened to upload.
  static const _markerWidthPx = 75;

  /// Keyed by hash rather than the source string itself — the keys would
  /// otherwise be megabytes of base64 held alongside the decoded bitmaps.
  static final Map<int, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor?> fromSource(String? source) async {
    final trimmed = source?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final key = trimmed.hashCode;
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final bytes = await _readBytes(trimmed);
      if (bytes == null || bytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: _markerWidthPx);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      final descriptor = BitmapDescriptor.bytes(data.buffer.asUint8List());
      _cache[key] = descriptor;
      return descriptor;
    } catch (_) {
      // Corrupt or unsupported art must never take the map down — callers fall
      // back to their default marker.
      return null;
    }
  }

  static Future<Uint8List?> _readBytes(String source) async {
    if (source.startsWith('data:')) {
      final comma = source.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(source.substring(comma + 1));
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse(source));
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final chunks = await response.toList();
        return Uint8List.fromList(chunks.expand((c) => c).toList());
      } finally {
        client.close(force: true);
      }
    }

    return null;
  }
}
