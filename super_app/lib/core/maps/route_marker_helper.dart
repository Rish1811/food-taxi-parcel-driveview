import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteMarkerHelper {
  RouteMarkerHelper._();

  static Future<BitmapDescriptor> createCustomPinWithLabel({
    required String labelText,
    required Color pinColor,
    required Color boxBgColor,
    required Color textColor,
    required String prefix,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final pixelRatio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    canvas.scale(pixelRatio, pixelRatio);

    const double paddingX = 12;
    const double paddingY = 6;
    const double pinSize = 22;
    const double pointerHeight = 8;
    const double borderRadius = 10;

    final prefixStyle = TextStyle(
      color: pinColor,
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );
    final prefixPainter = TextPainter(
      text: TextSpan(text: '$prefix: ', style: prefixStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final shortLabel = labelText;

    final labelStyle = TextStyle(
      color: textColor,
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: shortLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 200);

    final totalTextWidth = prefixPainter.width + labelPainter.width;
    final boxWidth = totalTextWidth + (paddingX * 2);
    final boxHeight = prefixPainter.height + (paddingY * 2);
    final totalHeight = boxHeight + pointerHeight + pinSize + 6;
    final totalWidth = boxWidth < 80 ? 80.0 : boxWidth;

    final centerX = totalWidth / 2;

    // 1. Box Shadow
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - (boxWidth / 2), 2, boxWidth, boxHeight),
      const Radius.circular(borderRadius),
    );
    canvas.drawRRect(boxRect.shift(const Offset(0, 2)), shadowPaint);

    // 2. Box Fill
    final bgPaint = Paint()..color = boxBgColor;
    canvas.drawRRect(boxRect, bgPaint);

    // 3. Box Border
    final borderPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(boxRect, borderPaint);

    // 4. Paint Text
    final textStartX = centerX - (boxWidth / 2) + paddingX;
    final textStartY = 2 + paddingY;
    prefixPainter.paint(canvas, Offset(textStartX, textStartY));
    labelPainter.paint(canvas, Offset(textStartX + prefixPainter.width, textStartY));

    // 5. Pointer Arrow
    final arrowPath = Path()
      ..moveTo(centerX - 5, 2 + boxHeight)
      ..lineTo(centerX + 5, 2 + boxHeight)
      ..lineTo(centerX, 2 + boxHeight + pointerHeight)
      ..close();
    final arrowPaint = Paint()..color = boxBgColor;
    canvas.drawPath(arrowPath, arrowPaint);

    // 6. Pin Circle
    final pinCenterY = 2 + boxHeight + pointerHeight + (pinSize / 2);
    final pinBgPaint = Paint()..color = pinColor;
    canvas.drawCircle(Offset(centerX, pinCenterY), pinSize / 2, pinBgPaint);

    final pinInnerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(centerX, pinCenterY), pinSize / 4, pinInnerPaint);

    final image = await pictureRecorder.endRecording().toImage(
          (totalWidth * pixelRatio).ceil(),
          (totalHeight * pixelRatio).ceil(),
        );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List(), imagePixelRatio: pixelRatio);
  }
}
