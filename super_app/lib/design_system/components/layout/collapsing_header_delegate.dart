import 'package:flutter/material.dart';

/// Renders [banner] behind a single fixed-height "sticky block" that travels
/// from its expanded position (floating over the banner) to its collapsed
/// position (pinned below the status bar) as the user scrolls, tracking
/// [shrinkOffset] 1:1 so it never desyncs or snaps. The banner fades and
/// drifts upward in the same motion, and a solid backdrop + shadow fade in
/// behind the block as it approaches fully collapsed, so the pinned header
/// reads as an elevated surface once the banner is gone.
///
/// Shared between Home and 99 Store so both screens scroll identically.
class CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  CollapsingHeaderDelegate({
    required this.expandedExtent,
    required this.collapsedExtent,
    required this.expandedBlockTop,
    required this.collapsedBlockTop,
    required this.blockHeight,
    required this.backdropColor,
    required this.banner,
    required this.stickyBlock,
    this.bannerDriftUp = 30,
  });

  final double expandedExtent;
  final double collapsedExtent;
  final double expandedBlockTop;
  final double collapsedBlockTop;
  final double blockHeight;
  final Color backdropColor;
  final Widget banner;
  final Widget stickyBlock;
  final double bannerDriftUp;

  @override
  double get maxExtent => expandedExtent;

  @override
  double get minExtent => collapsedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = expandedExtent - collapsedExtent;
    var t = range > 0 ? shrinkOffset / range : 1.0;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final blockTop =
        expandedBlockTop + (collapsedBlockTop - expandedBlockTop) * t;

    return ClipRect(
      child: Stack(
        children: [
          // Banner: fades out and drifts upward as the header collapses.
          Positioned(
            top: -t * bannerDriftUp,
            left: 0,
            right: 0,
            child: Opacity(opacity: 1 - t, child: banner),
          ),
          // Solid backdrop for the sticky block — fully transparent at rest
          // (so the expanded view is pixel-identical to before) and fades in
          // as the banner disappears, so the pinned block always has an
          // opaque surface behind it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: blockTop + blockHeight,
            // ColoredBox defaults to HitTestBehavior.opaque, so it would
            // swallow every tap underneath (even at opacity 0) unless
            // explicitly ignored — it only ever needs to be seen, not touched.
            child: IgnorePointer(
              child: Opacity(
                opacity: t,
                child: ColoredBox(color: backdropColor),
              ),
            ),
          ),
          // Sticky block, sliding as one unit; the shadow fades in smoothly
          // as it becomes pinned.
          Positioned(
            top: blockTop,
            left: 0,
            right: 0,
            height: blockHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: t <= 0
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08 * t),
                          blurRadius: 12,
                          offset: Offset(0, 4 * t),
                        ),
                      ],
              ),
              child: stickyBlock,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingHeaderDelegate oldDelegate) => true;
}
