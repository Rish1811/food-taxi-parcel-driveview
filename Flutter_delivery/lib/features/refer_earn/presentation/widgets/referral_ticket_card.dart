import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The referral ticket visual — used both while it's printing out of the
/// machine and on the final result page.
///
/// Renders assets/image/referral_ticket.png once that artwork is dropped
/// into the project; falls back to a hand-built ticket layout until then.
class ReferralTicketCard extends StatelessWidget {
  final double width;
  final double height;

  const ReferralTicketCard({
    super.key,
    required this.width,
    required this.height,
  });

  static const Color ticketColor = Color(0xFFE05F00); // AppColors.primaryDark

  /// assets/image/referral_ticket.png is 417x520px. Callers should size
  /// this widget to that same ratio (e.g. height = width / aspectRatio) so
  /// BoxFit.contain never has to letterbox — otherwise the rendered art
  /// sits smaller than its box, leaving a gap between the visible ticket
  /// edge and anything drawn to trace that edge (like RotatingTicketBorder).
  static const double aspectRatio = 417 / 520;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/image/referral_ticket.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => ClipPath(
          clipper: _TicketCardClipper(notch: 14.r),
          child: Container(color: ticketColor, child: _buildFallbackContent()),
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(height: 6.h),
          _buildTicketLogo(),
          _buildMascot(),
          _DashedDivider(color: Colors.white.withOpacity(0.35)),
          Column(
            children: [
              Text(
                'REFERRAL TICKET',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10.h),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  children: [
                    const TextSpan(text: 'Hey friend, '),
                    TextSpan(
                      text: '₹100',
                      style: const TextStyle(color: Color(0xFFFFD54F)),
                    ),
                    const TextSpan(text: '\nreferral cash for you.'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  Widget _buildTicketLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34.r,
          height: 34.r,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: Icon(
            Icons.location_on_rounded,
            color: ticketColor,
            size: 20.sp,
          ),
        ),
        SizedBox(width: 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Appzeto',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              'Food',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reserved for the delivery-partner mascot illustration. Drop the artwork
  // in as assets/image/referral_mascot.png and it renders automatically;
  // until then this falls back to a placeholder icon.
  Widget _buildMascot() {
    return SizedBox(
      height: 140.h,
      child: Image.asset(
        'assets/image/referral_mascot.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.delivery_dining_rounded,
          size: 90.sp,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: dashSpace / 2),
              child: Container(width: dashWidth, height: 1.5, color: color),
            ),
          ),
        );
      },
    );
  }
}

/// Traces the "ticket" outline: each corner has a small concave scalloped
/// notch bitten out of it, like a torn coupon stub. Shared by the clipper
/// below and by [RotatingTicketBorder] so the glow line follows the exact
/// same edge as the card itself.
Path ticketOutlinePath(Size size, double notch) {
  final w = size.width;
  final h = size.height;
  final r = Radius.circular(notch);

  return Path()
    ..moveTo(notch, 0)
    ..lineTo(w - notch, 0)
    ..arcToPoint(Offset(w, notch), radius: r, clockwise: false)
    ..lineTo(w, h - notch)
    ..arcToPoint(Offset(w - notch, h), radius: r, clockwise: false)
    ..lineTo(notch, h)
    ..arcToPoint(Offset(0, h - notch), radius: r, clockwise: false)
    ..lineTo(0, notch)
    ..arcToPoint(Offset(notch, 0), radius: r, clockwise: false)
    ..close();
}

/// Clips a rectangle into the ticket shape defined by [ticketOutlinePath].
class _TicketCardClipper extends CustomClipper<Path> {
  final double notch;
  const _TicketCardClipper({required this.notch});

  @override
  Path getClip(Size size) => ticketOutlinePath(size, notch);

  @override
  bool shouldReclip(covariant _TicketCardClipper oldClipper) =>
      oldClipper.notch != notch;
}
