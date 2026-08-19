import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/design_system/components/ride/loading_widget.dart';
import 'package:superapp_user/design_system/components/ride/app_bottom_navigation_bar.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_history_controller.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_history_state.dart';
import 'package:superapp_user/modules/rental/application/rental_providers.dart';
import 'package:superapp_user/modules/rental/data/models/rental_booking_model.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/widgets/recent_activity_card.dart';

/// Normalized history entry representing either a Ride or a Rental booking.
class _HistoryEntry {
  final String rideId;
  final String title;
  final String subtitle;
  final String pickup;
  final String drop;
  final DateTime date;
  final double fare;
  final String status;
  final String serviceType;
  final String? vehicleIconType;
  final String route;

  const _HistoryEntry({
    required this.rideId,
    required this.title,
    required this.subtitle,
    required this.pickup,
    required this.drop,
    required this.date,
    required this.fare,
    required this.status,
    required this.serviceType,
    this.vehicleIconType,
    required this.route,
  });

  factory _HistoryEntry.fromRide(RideModel ride) {
    final serviceType = (ride.serviceType ?? '').toLowerCase();
    final vehicle = ride.vehicleType ?? ride.vehicleIconType ?? '';

    String title;
    String subtitle;
    if (serviceType == 'parcel') {
      title = 'Parcel delivery';
      subtitle = 'DELIVERY BOOKING';
    } else if (serviceType == 'intercity' || serviceType == 'outstation') {
      title = 'Outstation Ride';
      subtitle = 'INTERCITY TRIP';
    } else if (serviceType == 'bus') {
      title = 'Bus Booking';
      subtitle = 'BUS TICKET';
    } else {
      title = vehicle.isEmpty ? 'Taxi Ride' : vehicle;
      subtitle = 'DRIVER TRIP';
    }

    return _HistoryEntry(
      rideId: ride.rideId,
      title: title,
      subtitle: subtitle,
      pickup: ride.pickupAddress,
      drop: ride.dropAddress,
      date: ride.completedAt ??
          ride.startedAt ??
          ride.acceptedAt ??
          ride.scheduledAt ??
          DateTime.now(),
      fare: ride.fare,
      status: ride.status,
      serviceType: serviceType,
      vehicleIconType: ride.vehicleIconType,
      route: '/rides/${ride.rideId}',
    );
  }

  factory _HistoryEntry.fromRental(RentalBookingModel booking) {
    return _HistoryEntry(
      rideId: booking.id,
      title: booking.vehicleName.isNotEmpty ? booking.vehicleName : 'Rental Vehicle',
      subtitle: booking.packageLabel.isNotEmpty
          ? booking.packageLabel.toUpperCase()
          : 'RENTAL BOOKING',
      pickup: booking.vehicleName,
      drop: booking.packageLabel,
      date: booking.pickupDateTime ?? booking.createdAt ?? DateTime.now(),
      fare: booking.totalCost,
      status: booking.status,
      serviceType: 'rental',
      route: '/rental/history',
    );
  }
}

class _HistoryFilter {
  final String id;
  final String label;

  /// Category query sent to backend (null means not fetched from ride API)
  final String? rideCategory;
  final bool includesRentals;

  const _HistoryFilter({
    required this.id,
    required this.label,
    this.rideCategory,
    this.includesRentals = false,
  });
}

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  final _scrollController = ScrollController();

  static const _filters = <_HistoryFilter>[
    _HistoryFilter(id: 'all', label: 'ALL', rideCategory: 'all', includesRentals: true),
    _HistoryFilter(id: 'rides', label: 'RIDES', rideCategory: 'rides'),
    _HistoryFilter(id: 'parcels', label: 'PARCELS', rideCategory: 'parcels'),
    _HistoryFilter(id: 'rental', label: 'RENTAL', includesRentals: true),
    _HistoryFilter(id: 'outstation', label: 'OUTSTATION', rideCategory: 'outstation'),
    _HistoryFilter(id: 'bus', label: 'BUS', rideCategory: 'bus'),
  ];

  String _selectedId = 'all';

  _HistoryFilter get _selected =>
      _filters.firstWhere((f) => f.id == _selectedId, orElse: () => _filters.first);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_selected.rideCategory == null) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(rideHistoryControllerProvider.notifier).loadNextPage();
    }
  }

  void _onFilterSelected(String id) {
    if (id == _selectedId) return;
    setState(() => _selectedId = id);

    final filter = _filters.firstWhere((f) => f.id == id);
    if (filter.rideCategory != null) {
      ref.read(rideHistoryControllerProvider.notifier).setCategory(filter.rideCategory!);
    }
  }

  List<_HistoryEntry> _entriesFor(
    _HistoryFilter filter,
    RideHistoryState rideState,
    List<RentalBookingModel> rentals,
  ) {
    final entries = <_HistoryEntry>[];

    if (filter.rideCategory != null) {
      final rides = rideState.rides.map(_HistoryEntry.fromRide);
      if (filter.id == 'all') {
        entries.addAll(rides);
      } else if (filter.id == 'rides') {
        entries.addAll(rides.where((e) =>
            e.serviceType != 'parcel' &&
            e.serviceType != 'intercity' &&
            e.serviceType != 'outstation' &&
            e.serviceType != 'bus' &&
            e.serviceType != 'rental'));
      } else if (filter.id == 'parcels') {
        entries.addAll(rides.where((e) => e.serviceType == 'parcel'));
      } else if (filter.id == 'outstation') {
        entries.addAll(rides.where((e) =>
            e.serviceType == 'outstation' || e.serviceType == 'intercity'));
      } else if (filter.id == 'bus') {
        entries.addAll(rides.where((e) => e.serviceType == 'bus'));
      } else {
        entries.addAll(rides);
      }
    }

    if (filter.includesRentals) {
      entries.addAll(rentals.map(_HistoryEntry.fromRental));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideHistoryControllerProvider);
    final rentalsAsync = ref.watch(myRentalBookingsProvider);
    final filter = _selected;

    final rentals = rentalsAsync.value ?? const <RentalBookingModel>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? TaxiColors.darkBackground : TaxiColors.lightBackground;
    final textPrimary = isDark ? TaxiColors.darkTextPrimary : TaxiColors.lightTextPrimary;
    final textSecondary = isDark ? TaxiColors.darkTextSecondary : TaxiColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'MY BOOKINGS',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        leading: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back, color: textPrimary, size: 20),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 2),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your recent trips, deliveries, and bookings',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _FilterBar(
            filters: _filters,
            selectedId: _selectedId,
            onSelected: _onFilterSelected,
          ),
          Expanded(
            child: _buildBody(filter, rideState, rentals, rentalsAsync.isLoading),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    _HistoryFilter filter,
    RideHistoryState rideState,
    List<RentalBookingModel> rentals,
    bool rentalsLoading,
  ) {
    final loading = filter.rideCategory != null
        ? rideState.isLoading
        : rentalsLoading;
    if (loading) {
      return const LoadingWidget(message: 'Loading your bookings…');
    }

    final entries = _entriesFor(filter, rideState, rentals);

    if (entries.isEmpty && rideState.error != null && filter.rideCategory != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load your bookings',
        message: 'Please check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _refresh,
      );
    }

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No bookings yet',
        message: filter.id == 'all'
            ? 'Your trips will appear here once you make your first booking.'
            : 'Nothing under ${filter.label} yet.',
        actionLabel: 'Book now',
        onAction: () => context.go('/taxi'),
      );
    }

    final showFooterLoader = filter.rideCategory != null && rideState.isLoadingMore;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: entries.length + (showFooterLoader ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final entry = entries[index];
          return RecentActivityCard(
            title: entry.title,
            subtitle: entry.subtitle,
            pickup: entry.pickup,
            drop: entry.drop,
            date: entry.date,
            fare: entry.fare,
            status: entry.status,
            serviceType: entry.serviceType,
            vehicleIconType: entry.vehicleIconType,
            onTap: () {
              if (entry.route.isNotEmpty) {
                context.push(entry.route);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(myRentalBookingsProvider);
    if (_selected.rideCategory != null) {
      await ref.read(rideHistoryControllerProvider.notifier).loadFirstPage();
    }
  }
}

class _FilterBar extends StatelessWidget {
  final List<_HistoryFilter> filters;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _FilterBar({
    required this.filters,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? TaxiColors.primary : const Color(0xFF0F172A);
    final unselectedBg = isDark ? TaxiColors.darkSurface : Colors.white;
    final unselectedText = isDark ? TaxiColors.darkTextSecondary : const Color(0xFF475569);
    final unselectedBorder = isDark ? TaxiColors.darkBorder : const Color(0xFFE2E8F0);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final selected = filter.id == selectedId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: selected,
                onSelected: (_) => onSelected(filter.id),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : unselectedText,
                ),
                selectedColor: selectedBg,
                backgroundColor: unselectedBg,
                side: BorderSide(
                  color: selected ? Colors.transparent : unselectedBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
