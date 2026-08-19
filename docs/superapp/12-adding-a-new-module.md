# Chapter 19 — Adding a New Module (manual playbook)

How to add a fifth module — `bus`, `pooling`, `grocery`, `hotel`, `medicine`, whatever comes next — by hand, without touching food, taxi, parcel or rental.

The whole point of the `AppModule` contract is that this is **one folder plus one line**. If adding a module ever requires editing the router, the push handler, the profile screen, the activity screen, or the search screen, something has drifted from the design and should be fixed there rather than worked around here.

Worked example throughout: **`bus`** — chosen because your taxi backend already exposes `/users/buses`, `/users/buses/routes`, `/users/buses/search`, `/users/buses/:id/seats`, `/users/bus-bookings`, `/users/bus-bookings/order`, `/users/bus-bookings/verify` with **zero client code**. It is the most likely real third module.

---

## 19.0 Step zero — is this actually a module?

Ask three questions before creating a folder. Getting this wrong is the most expensive mistake in the chapter, because unwinding a module is much harder than promoting a feature.

| Question | If **yes** | If **no** |
|---|---|---|
| Does it have its own **booking/ordering funnel** that ends in a job the user tracks or receives? | module | probably a feature |
| Would it deserve its **own tile on the hub**, and would a user say "I'm using the bus thing" as a distinct product? | module | probably a feature |
| Does it own **its own backend resource** (`/buses`, `/bus-bookings`) rather than extending an existing one? | module | probably a feature |

Worked judgements:

| Candidate | Verdict | Why |
|---|---|---|
| **Bus ticketing** | ✅ module | Own funnel (route → seats → passengers → pay), own hub tile, own endpoints |
| **Pooling / shared rides** | ⚠️ borderline | Own endpoints and funnel, but conceptually a *ride type*. If it shares the pickup/drop picker and the driver-tracking screen, make it a **variant inside `modules/taxi`** with its own repository, not a module. If it has its own route/seat model, make it a module |
| **Grocery / pharmacy** | ✅ module | Different catalogue shape, different cart rules, different fulfilment — even though it superficially resembles food |
| **Store99** | ❌ not a module | It is already a tab inside food's shell, sharing food's cart, checkout, and order model. Leave it in `modules/food` |
| **Subscriptions** | ❌ not a module | Cuts across every module → `shared/subscription` |
| **Insurance add-on at checkout** | ❌ not a module | A step in an existing funnel |
| **Loyalty tier / rewards** | ❌ not a module | `shared/referral` or `shared/offers` |

**The tell for "not a module": it needs to read another module's state.** If `pooling` needs `modules/taxi`'s booking controller, it is not a separate module — the boundary lint will tell you so on your first build, and that is the design working as intended.

If it fails the test but you still want it isolated, put it in `shared/` (cross-module feature) or as a sub-feature folder inside the module it belongs to.

---

## 19.1 The checklist

Thirteen steps. Steps 1–7 make the module exist; 8–13 wire it into the cross-cutting systems. **Steps 8–13 are all optional** — a module that contributes nothing to search still works; it just won't appear in search.

```
 1. Register the identity        ModuleId + ModuleAccent enum entries
 2. Scaffold the folder          modules/bus/{api,data,application,presentation}
 3. Endpoints + datasource       api/bus_endpoints.dart, api/datasources/
 4. Models + repository          data/models/, data/repositories/
 5. Controllers                  application/*_controller.dart + bus_providers.dart
 6. Screens                      presentation/
 7. Routes + module class        bus_routes.dart + bus_module.dart
 8. Register it                  ONE line in module_registry.dart
 9. Push routing                 resolvePush()
10. Realtime                     socketBinding()
11. Activity feed                activitySources()
12. Search / profile / wallet    searchSources() · profileSections() · walletHistorySources()
13. Assets, flags, strings, native
```

Expect **2–5 days** for a module of bus's size once the platform exists — most of it in step 6 (screens). Steps 1, 2, 7, 8 are under an hour combined.

---

## 19.2 Step 1 — Register the identity

Two enums. These are the only files outside `modules/bus/` you touch in the first seven steps.

```dart
// lib/modules/module_id.dart
enum ModuleId {
  food, taxi, parcel, rental,
  bus;                                          // ← add

  static ModuleId? tryParse(String? raw) {
    if (raw == null) return null;
    for (final v in values) { if (v.name == raw) return v; }
    return null;
  }

  /// '/bus/rides/12' → ModuleId.bus
  static ModuleId? fromPath(String location) {
    final seg = Uri.parse(location).pathSegments.firstOrNull;
    return seg == null ? null : tryParse(seg);
  }
}
```

```dart
// lib/design_system/tokens/module_accent.dart
enum ModuleAccent {
  hub   (Color(0xFFFF7A00), Color(0xFFFF8A1D)),
  food  (Color(0xFFFF7A00), Color(0xFFFF8A1D)),
  taxi  (Color(0xFFFF5C2B), Color(0xFFE04313)),
  parcel(Color(0xFFF59E0B), Color(0xFFD97706)),
  rental(Color(0xFF3B82F6), Color(0xFF2563EB)),
  bus   (Color(0xFF8B5CF6), Color(0xFF7C3AED));   // ← add
  const ModuleAccent(this.primary, this.primaryVariant);
  final Color primary, primaryVariant;
}
```

> **Rule.** `ModuleId.name` is the route prefix, the push discriminator, the activity tag, and the analytics dimension — all four at once. Pick it once, lowercase, singular, and **never rename it**. A rename invalidates deep links in the wild, push payloads already queued on FCM's servers, and historical analytics.

---

## 19.3 Step 2 — Scaffold

```
lib/modules/bus/
├── bus_module.dart                 ← the contract implementation (step 7)
├── bus_routes.dart                 ← route subtree (step 7)
├── bus_route_names.dart            ← named-route constants
├── api/
│   ├── bus_endpoints.dart
│   ├── bus_socket_events.dart      ← only if the module needs realtime
│   └── datasources/
│       ├── bus_catalog_datasource.dart
│       └── bus_booking_datasource.dart
├── data/
│   ├── models/
│   │   ├── bus_route.dart
│   │   ├── bus_trip.dart
│   │   ├── bus_seat.dart
│   │   ├── bus_passenger.dart
│   │   └── bus_booking.dart
│   └── repositories/
│       ├── bus_catalog_repository.dart
│       └── bus_booking_repository.dart
├── application/
│   ├── bus_providers.dart
│   ├── bus_search_controller.dart
│   ├── seat_selection_controller.dart
│   ├── bus_booking_controller.dart
│   ├── bus_activity_source.dart    ← step 11
│   └── bus_push_router.dart        ← step 9 (if the mapping is non-trivial)
└── presentation/
    ├── bus_home_screen.dart
    ├── trip_results_screen.dart
    ├── seat_map_screen.dart
    ├── passenger_details_screen.dart
    ├── booking_review_screen.dart
    ├── ticket_screen.dart
    └── widgets/
        ├── seat_grid.dart
        ├── trip_card.dart
        └── bus_activity_row.dart   ← step 11
```

### The import rules for this folder

```
modules/bus/**  MAY import   core/**  design_system/**  shared/**
                MUST NOT     modules/food/**  modules/taxi/**
                             modules/parcel/**  modules/rental/**
```

Verify it before you write a line of screen code — add the module to the existing CI greps and confirm they pass while empty:

```bash
! grep -rE "import .*modules/(food|taxi|parcel|rental)/" lib/modules/bus
```

If you later find you *need* another module's code, one of three things is true, in order of likelihood: it belongs in `shared/`, it belongs in `core/`, or this is not a module (§19.0).

---

## 19.4 Step 3 — Endpoints and datasources

```dart
// lib/modules/bus/api/bus_endpoints.dart
class BusEndpoints {
  const BusEndpoints._();

  static const String routes        = '/users/buses/routes';
  static const String search        = '/users/buses/search';
  static String seats(String tripId) => '/users/buses/$tripId/seats';

  static const String bookings      = '/users/bus-bookings';
  static const String createOrder   = '/users/bus-bookings/order';
  static const String verifyPayment = '/users/bus-bookings/verify';
  static String bookingById(String id) => '$bookings/$id';
}
```

> Endpoint constants live **in the module**, not in `core/config`. "Which URL serves bus trips" is module knowledge. `core/config` only knows *hosts*.

```dart
// lib/modules/bus/api/datasources/bus_catalog_datasource.dart
class BusCatalogDataSource {
  final ApiClient _api;
  const BusCatalogDataSource(this._api);

  Future<List<BusTrip>> search({
    required String fromCityId,
    required String toCityId,
    required DateTime date,
  }) async {
    final data = await _api.get<List<dynamic>>(
      BusEndpoints.search,
      query: {
        'from': fromCityId,
        'to': toCityId,
        'date': date.toIso8601String().substring(0, 10),
      },
      cacheTtl: const Duration(minutes: 5),   // see the cache policy, Ch. 9 §9.6
    );
    return data.map((e) => BusTrip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusSeat>> seats(String tripId) async {
    // NO cacheTtl — seat availability is mutable and money-adjacent.
    final data = await _api.get<List<dynamic>>(BusEndpoints.seats(tripId));
    return data.map((e) => BusSeat.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

Three things the shared `ApiClient` gives you for free — do not reimplement any of them:

- the `{success, message, data}` envelope is already unwrapped, so `fromJson` sees `data` directly
- errors arrive as typed `Failure`s (`ValidationFailure` carries per-field messages from express-validator)
- `cacheTtl` opts into the disk-backed GET cache with instant-paint `peek()` and offline fallback

**Never cache anything mutable or monetary.** Seat availability, bookings, wallet, and prices are `cacheTtl: null`.

---

## 19.5 Step 4 — Models and repositories

```dart
// lib/modules/bus/data/models/bus_trip.dart
class BusTrip {
  final String id, operatorName, busType;
  final String fromCity, toCity;
  final DateTime departsAt, arrivesAt;
  final int farePaise;                 // ← integer paise. NEVER double for money
  final int seatsAvailable;
  final double rating;

  const BusTrip({ /* … */ });

  factory BusTrip.fromJson(Map<String, dynamic> json) => BusTrip(
    id:           (json['_id'] ?? json['id'] ?? '').toString(),
    operatorName: (json['operator'] ?? '').toString(),
    busType:      (json['busType'] ?? '').toString(),
    fromCity:     (json['from'] ?? '').toString(),
    toCity:       (json['to'] ?? '').toString(),
    departsAt:    DateTime.tryParse('${json['departsAt']}') ?? DateTime.now(),
    arrivesAt:    DateTime.tryParse('${json['arrivesAt']}') ?? DateTime.now(),
    farePaise:    _paise(json['fare']),
    seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
    rating:       (json['rating'] as num?)?.toDouble() ?? 0,
  );

  static int _paise(dynamic v) =>
      v is num ? (v * 100).round() : ((num.tryParse('$v') ?? 0) * 100).round();
}
```

House rules, all learned from the existing code:

- **Money is `int` paise, never `double`.** Both existing apps parse amounts as `double` and it is a latent bug (`₹349.99999`). Do not inherit it.
- **Tolerant `fromJson`.** Both backends return `_id` *or* `id`, and mix `camelCase`/`snake_case`. Accept both; never `as String` on something that may be an `int`.
- **Resolve media paths through `ApiConfig.resolveMedia`** — the API mixes absolute URLs and relative `/uploads/…` paths.
- **No `freezed`/`json_serializable`.** Neither app uses them (they were declared and deleted in Phase 1). Stay consistent — hand-written `fromJson` is the house style here.

```dart
// lib/modules/bus/data/repositories/bus_booking_repository.dart
class BusBookingRepository {
  final BusBookingDataSource _remote;
  const BusBookingRepository(this._remote);

  Future<BusBooking> create({
    required String tripId,
    required List<String> seatIds,
    required List<BusPassenger> passengers,
    String? couponCode,
  }) => _remote.create(
        tripId: tripId, seatIds: seatIds,
        passengers: passengers, couponCode: couponCode,
      );

  Future<List<BusBooking>> history({String? cursor}) =>
      _remote.list(cursor: cursor);
}
```

The repository owns orchestration (cache policy, merges, pagination). The datasource owns HTTP. **Do not create an abstract repository interface** — Phase 4 deleted the six food ones because they existed only to be implemented once; Riverpod overrides are what makes this testable.

---

## 19.6 Step 5 — Controllers

Riverpod 3 `Notifier` / `AsyncNotifier`. Never `StateNotifier` — it is gone.

```dart
// lib/modules/bus/application/bus_providers.dart
final busCatalogDataSourceProvider = Provider((ref) =>
    BusCatalogDataSource(ref.watch(apiClientProvider(BusModule.endpointIdConst))));

final busCatalogRepositoryProvider = Provider((ref) =>
    BusCatalogRepository(ref.watch(busCatalogDataSourceProvider)));

final busSearchControllerProvider =
    NotifierProvider<BusSearchController, BusSearchState>(BusSearchController.new);

/// Per-trip seat map — family + autoDispose, because each holds a decent
/// chunk of state and the user browses several trips per session.
final seatSelectionControllerProvider = NotifierProvider.autoDispose
    .family<SeatSelectionController, SeatSelectionState, String>(
        SeatSelectionController.new);
```

```dart
// lib/modules/bus/application/bus_booking_controller.dart
class BusBookingController extends Notifier<BusBookingState> {
  @override
  BusBookingState build() {
    // build() re-runs on every dependency invalidation — it is NOT a constructor.
    // Wiring here must be idempotent, with matching teardown.
    ref.onDispose(_cancelInFlight);

    // Restore a half-finished booking so leaving the module doesn't lose it.
    final draft = ref.read(boxStoreProvider).busDraft();
    return draft ?? const BusBookingState.empty();
  }

  Future<void> confirm() async {
    state = state.copyWith(submitting: true);
    try {
      final booking = await ref.read(busBookingRepositoryProvider).create(
        tripId: state.tripId!, seatIds: state.seatIds,
        passengers: state.passengers, couponCode: state.coupon?.code,
      );

      final result = await ref.read(paymentGatewayProvider).pay(
        PaymentIntent(
          module: ModuleId.bus,                 // ← attribution. Always set it.
          purpose: 'bus_booking',
          amountPaise: booking.totalPaise,
          jobId: booking.id,
        ),
      );

      if (result.isSuccess) {
        // Server-side verify. NEVER trust the gateway callback alone.
        await ref.read(busBookingRepositoryProvider).verify(booking.id, result);
        ref.read(appEventsProvider.notifier)
           .emit(AppEvent.jobStarted(ModuleId.bus, booking.id));
        ref.read(boxStoreProvider).clearBusDraft();
        state = state.copyWith(submitting: false, bookingId: booking.id);
      }
    } on Failure catch (f) {
      state = state.copyWith(submitting: false, error: f.message);
    }
  }
}
```

Five rules, each of which corresponds to a bug that already exists somewhere in the current apps:

1. **`build()` is not a constructor.** It re-runs. Side effects go behind `Future.microtask` or an explicit method; every subscription/timer/socket room gets a matching `ref.onDispose`.
2. **Every `PaymentIntent` carries `module`.** That is what makes one wallet ledger and one receipt list attribute correctly.
3. **Always round-trip to the server `verify` endpoint** before treating money as received.
4. **Persist the funnel draft, don't hold it.** Module scope disposes on exit; a Hive draft survives that *and* an app kill. Taxi's booking funnel loses everything today.
5. **Emit `AppEvent`s** rather than reaching into `shared/`. `activeJobsController` and `walletController` are listening.

---

## 19.7 Step 6 — Screens

Build from `design_system/components/` only. If you find yourself writing a button, a text field, an empty state, a skeleton, a bottom sheet, a snackbar, a search field, or a map — **stop; it exists.**

```dart
import 'package:superapp_user/design_system/components/buttons/app_button.dart';
import 'package:superapp_user/design_system/components/inputs/search_field.dart';
import 'package:superapp_user/design_system/components/skeletons/list_skeleton.dart';
import 'package:superapp_user/design_system/components/media/empty_state.dart';
import 'package:superapp_user/design_system/theme/app_theme_extension.dart';

class TripResultsScreen extends ConsumerWidget {
  const TripResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;   // NOT AppColors — that façade is deprecated
    final state = ref.watch(busSearchControllerProvider);

    return Scaffold(
      appBar: const AppTopBar(title: 'Buses'),
      body: switch (state) {
        BusSearchLoading() => const ListSkeleton(itemCount: 6),
        BusSearchEmpty()   => const EmptyState(
            title: 'No buses on this route',
            subtitle: 'Try a different date',
            asset: 'assets/images/shared/empty_search.webp'),
        BusSearchError(:final message) =>
            ErrorState(message: message, onRetry: () =>
                ref.read(busSearchControllerProvider.notifier).retry()),
        BusSearchData(:final trips) => ListView.builder(
            itemExtent: 148,                      // fixed extent → cheaper layout
            itemCount: trips.length,
            itemBuilder: (c, i) => TripCard(
              trip: trips[i],
              onTap: () => context.pushNamed(
                BusRouteNames.seatMap,
                pathParameters: {'tripId': trips[i].id},
                extra: trips[i],                  // warm push, avoids a refetch
              ),
            ),
          ),
      },
    );
  }
}
```

Screen rules:

- `context.palette`, never `AppColors` (deprecated façade) and never raw `Color(0xFF…)` literals.
- Spacing/radius from `design_system/tokens/`, not magic numbers.
- `flutter_screenutil` (`.w`/`.h`/`.sp`) is **food-module only**. New modules use logical pixels and spacing tokens. Do not add a second `ScreenUtilInit`.
- Keep files under ~400 lines. The existing 2,629-line `cart_screen.dart` is what happens otherwise.
- `pushNamed`, not raw path strings.

---

## 19.8 Step 7 — Routes and the module class

### Route names

```dart
// lib/modules/bus/bus_route_names.dart
class BusRouteNames {
  const BusRouteNames._();
  static const home       = 'bus.home';
  static const results    = 'bus.results';
  static const seatMap    = 'bus.seats';
  static const passengers = 'bus.passengers';
  static const review     = 'bus.review';
  static const ticket     = 'bus.ticket';
}
```

### Routes

```dart
// lib/modules/bus/bus_routes.dart
List<RouteBase> busRoutes(GlobalKey<NavigatorState> rootKey) => [
  GoRoute(
    name: BusRouteNames.home, path: '/bus',
    builder: (c, s) => const BusHomeScreen(),
  ),
  GoRoute(
    name: BusRouteNames.results, path: '/bus/trips',
    builder: (c, s) => TripResultsScreen(
      from: s.uri.queryParameters['from'],
      to:   s.uri.queryParameters['to'],
      date: DateTime.tryParse(s.uri.queryParameters['date'] ?? ''),
    ),
  ),
  GoRoute(
    name: BusRouteNames.seatMap, path: '/bus/trips/:tripId/seats',
    builder: (c, s) {
      final extra = s.extra;
      // Warm push carries the model; a cold deep link carries only the id.
      // ALWAYS provide the loader branch — never cast `extra` unconditionally.
      return extra is BusTrip
          ? SeatMapScreen(trip: extra)
          : SeatMapLoaderScreen(tripId: s.pathParameters['tripId']!);
    },
  ),
  GoRoute(
    name: BusRouteNames.ticket, path: '/bus/bookings/:id',
    builder: (c, s) => BusTicketScreen(bookingId: s.pathParameters['id']!),
  ),
];
```

> **Every route path starts with `/bus`. No exceptions.** That is what makes the module's ownership readable from any URL and guarantees it cannot collide with the other four.
>
> **Every `:id` route must work from the id alone.** A push notification, a shared link, and a cold start all arrive without `extra`. Taxi shipped three unguarded `state.extra` casts and each is a crash on a cold deep link.

### The module class

```dart
// lib/modules/bus/bus_module.dart
class BusModule implements AppModule {
  const BusModule();

  static const endpointIdConst = BackendIds.unified;

  @override ModuleId     get id         => ModuleId.bus;
  @override String       get label      => 'Bus';
  @override String       get iconAsset  => 'assets/images/bus/tile.webp';
  @override ModuleAccent get accent     => ModuleAccent.bus;
  @override String       get endpointId => endpointIdConst;
  @override String       get entryRoute => '/bus';

  @override
  List<RouteBase> routes(GlobalKey<NavigatorState> rootKey) => busRoutes(rootKey);

  @override
  List<Override> providerOverrides() => const [];

  @override
  bool isEnabled(FeatureFlags flags) => flags.isOn('module.bus');

  // ── steps 9–12 below ──────────────────────────────────────────────
  @override PushRoute? resolvePush(PushMessage m) => …;      // §19.10
  @override SocketBinding? socketBinding() => null;          // §19.11
  @override List<ActivitySource> activitySources() => …;     // §19.12
  @override List<SearchSource> searchSources() => …;         // §19.13
  @override List<ProfileSection> profileSections() => …;     // §19.13
  @override List<WalletHistorySource> walletHistorySources() => const [];

  @override
  Future<void> warmUp(Ref ref) async {
    // Runs ONCE, on first entry into /bus/*. Not at app boot.
    await ref.read(boxStoreProvider).open('bus_recent_routes');
    unawaited(ref.read(busCityListProvider.future));   // prefetch, don't await
  }

  @override
  Future<void> cooldown(Ref ref) async {
    ref.read(busImageCacheProvider).evict();
  }
}
```

---

## 19.9 Step 8 — Register it

**One line.**

```dart
// lib/modules/module_registry.dart
final moduleRegistryProvider = Provider<ModuleRegistry>((ref) => ModuleRegistry(const [
  FoodModule(),
  TaxiModule(),
  ParcelModule(),
  RentalModule(),
  BusModule(),          // ← this is the entire integration
]));
```

At this point, without touching any other file, the module gets:

- its routes mounted, wrapped in its own `ProviderScope` (module DI) and `ModuleTheme` (module accent)
- a hub tile, ordered and gated by its feature flag
- push routing, if `resolvePush` is implemented
- a socket connection + room bindings, if `socketBinding` is implemented
- rows in the unified Activity feed and a tab, if `activitySources` is implemented
- results in unified search, if `searchSources` is implemented
- a section on the shared Profile screen, if `profileSections` is implemented
- controller disposal on module exit, for free
- wallet, payment, address picker, support chat, notifications, coupons — all shared, no work

**If you had to edit anything else to get the module to appear, that is a bug in the platform layer.** Fix it there.

---

## 19.10 Step 9 — Push routing

```dart
@override
PushRoute? resolvePush(PushMessage m) {
  // 1. Decline anything explicitly addressed to another module.
  if (m.module != null && m.module != ModuleId.bus) return null;

  // 2. Decline anything whose type isn't ours, so a missing `module`
  //    field doesn't make this module greedy.
  if (!m.type.startsWith('bus_')) return null;

  final id = m.string('jobId') ?? m.string('bookingId');
  if (id == null || id.isEmpty) return null;

  return switch (m.type) {
    'bus_booking_confirmed' ||
    'bus_departure_reminder' ||
    'bus_boarding_open'      => PushRoute('/bus/bookings/$id'),
    'bus_booking_cancelled'  => PushRoute('/activity?tab=bus'),
    _ => null,
  };
}
```

Rules:

- **Return `null` to decline.** The registry tries modules in order and the first non-null wins, so a greedy module silently steals another's notifications.
- **Guard on `module` *and* `type`.** `module` may be absent on legacy payloads; the type prefix is the fallback.
- **Never route to a screen that cannot load from the id alone** (§19.8).

Ask the backend for a channel and a payload shape:

```json
{
  "notification": { "title": "Your bus departs in 1 hour", "body": "…" },
  "data": {
    "module": "bus",
    "type": "bus_departure_reminder",
    "jobId": "665f…",
    "deepLink": "/bus/bookings/665f…",
    "android_channel_id": "bus_updates"
  },
  "android": { "notification": { "channel_id": "bus_updates" } }
}
```

Add the channel next to the existing six:

```dart
// lib/core/push/push_channels.dart
static const busUpdates = AndroidNotificationChannel(
    'bus_updates', 'Bus bookings', importance: Importance.max);
```

---

## 19.11 Step 10 — Realtime (only if needed)

Bus ticketing probably needs **no socket** — a confirmed ticket does not move. Return `null` and skip this section; that is the correct answer for most modules.

If the module genuinely needs live updates (live bus tracking, seat-lock contention):

```dart
@override
SocketBinding? socketBinding() => SocketBinding(
  endpointId: endpointIdConst,
  namespace: '/bus',
  events: const {'bus:trip:location', 'bus:seat:locked', 'bus:seat:released'},
  onConnect: (channel, ref) {
    // Rooms are per-connection — a reconnect gets a NEW socket id and the
    // server drops every room. Re-join here, or the module goes silently deaf.
    final id = ref.read(activeBusTripIdProvider);
    if (id != null) channel.emit('bus:trip:join', {'tripId': id});
  },
  onEvent: (event, payload, ref) =>
      ref.read(busSocketRouterProvider).dispatch(event, payload),
);
```

Two non-negotiables, both learned the hard way in the existing apps:

- **Re-join every room in `onConnect`**, which fires on connect *and* reconnect.
- **Sockets are an accelerator; REST is the contract.** Any screen driven by socket events must also poll and must reconcile on foreground — a backgrounded socket is paused, so events were missed. Never let a socket event alone change money or status; use it to trigger a refetch.

---

## 19.12 Step 11 — Activity feed

```dart
// lib/modules/bus/application/bus_activity_source.dart
class BusActivitySource implements ActivitySource {
  const BusActivitySource();

  @override ModuleId get module => ModuleId.bus;

  @override
  Future<ActivityPage> fetch({String? cursor, ActivityFilter? filter}) async {
    final page = await _repo.history(cursor: cursor);
    return ActivityPage(
      items: page.items.map((b) => ActivityItem(
        module: ModuleId.bus,
        id: b.id,
        kind: ActivityKind.busBooking,
        createdAt: b.createdAt,
        status: _status(b),
        title: '${b.fromCity} → ${b.toCity}',
        subtitle: '${b.operatorName} · ${b.seatCount} seat(s)',
        amountPaise: b.totalPaise,
        detailRoute: '/bus/bookings/${b.id}',
        trackRoute: b.isUpcoming ? '/bus/bookings/${b.id}' : null,
        actions: [
          if (b.isUpcoming) ActivityAction.cancel,
          if (b.isCompleted) ActivityAction.rebook,
          ActivityAction.invoice,
          ActivityAction.help,
        ],
        raw: b.toJson(),
      )).toList(),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Widget? buildTile(BuildContext c, ActivityItem item) =>
      BusActivityRow(item: item);       // return null to use the generic row

  @override
  Future<void> handleAction(ActivityAction a, ActivityItem i, Ref ref) async {
    switch (a) {
      case ActivityAction.rebook: await ref.read(busBookingControllerProvider
          .notifier).prefillFrom(i.raw); break;
      case ActivityAction.cancel: await ref.read(busBookingRepositoryProvider)
          .cancel(i.id); break;
      default: break;                    // shared handles invoice + help
    }
  }
}
```

`activitySources()` returning a non-empty list also creates the **"Bus" tab** on `/activity` and feeds `ActiveJobsController` (so an upcoming departure shows a floating card). Nothing in `shared/activity` changes.

---

## 19.13 Step 12 — Search, profile, wallet

All three optional. Implement what makes sense.

```dart
@override
List<SearchSource> searchSources() => const [BusRouteSearchSource()];
// Contributes a "Bus routes" section to /search. Query in parallel, cheap,
// and return fast — one slow source must not hold up the results list.

@override
List<ProfileSection> profileSections() => [
  ProfileSection(
    module: ModuleId.bus,
    title: 'Bus',
    icon: Icons.directions_bus_rounded,
    order: 50,
    entries: [
      ProfileEntry('My tickets',     route: '/activity?tab=bus'),
      ProfileEntry('Saved travellers', route: '/bus/travellers'),
    ],
  ),
];

@override
List<WalletHistorySource> walletHistorySources() => const [];
// Empty is correct when the unified ledger already tags entries with
// `module: bus` from the PaymentIntent. Only implement this if the module
// has its own ledger, which it should not.
```

---

## 19.14 Step 13 — Assets, flags, strings, native

### Assets

```
assets/images/bus/
├── tile.webp              hub tile icon
├── empty_trips.webp
└── seat_sprites.webp
```

```yaml
# pubspec.yaml — enumerate, never `- assets/`
flutter:
  assets:
    - assets/images/bus/
```

- **WebP at the rendered size.** Taxi shipped a 2.2 MB PNG for a map marker; do not repeat it.
- Re-run `flutter build appbundle --release --analyze-size` and confirm the module's asset contribution is what you expect.

### Feature flag

Server-driven, so the module can be dark-launched and killed without a release:

```json
{ "flags": { "module.bus": { "enabled": true, "minVersion": "2.4.0" } } }
```

`isEnabled(flags)` gates the hub tile *and* the routes — a deep link into a disabled module hits `errorBuilder`, which is the correct behaviour for a staged rollout.

### Strings

Until the localisation project lands, new modules ship English literals like everything else — **but keep every user-facing string in the widget, not buried in a controller or a model**, so extraction is mechanical later. Do not add hardcoded strings to `shared/` or `design_system/`; the CI check will flag those.

### Native

Usually nothing. Only if the module needs a capability no existing module has:

| Need | Action |
|---|---|
| A new runtime permission (camera, contacts) | Add to `AndroidManifest.xml` + iOS `Info.plist`, and route it through `core/permissions/permission_service.dart` — never call `permission_handler` from a module |
| A new payment method | Add an adapter under `core/payment/adapters/`, not in the module |
| A new native SDK | It belongs in `core/`, wrapped, with the module depending on the wrapper |

If a module needs a native dependency of its own, that is a signal it should be a package, not a folder — see §19.18.

---

## 19.15 Backend contract to request

Hand this to the backend team when the module is scoped. Every item exists because the platform already assumes it.

| # | Request | Why |
|---|---|---|
| 1 | Endpoints under a namespace that collides with nothing (`/users/buses/*`, `/users/bus-bookings/*`) | Path collisions across modules are unrecoverable |
| 2 | The standard `{success, message, data}` envelope | `ApiClient` unwraps it; a non-conforming endpoint needs a special case |
| 3 | `GET /users/bus-bookings?cursor=` — **cursor pagination, not page numbers** | The activity feed merges by cursor |
| 4 | Bookings included in the unified `GET /activity` with `module: "bus"` | Otherwise activity pagination degrades to an approximate client-side merge |
| 5 | Every push payload carries `module: "bus"`, one canonical `jobId`, and `android_channel_id` | Push routing and per-module notification settings |
| 6 | Payments debit the **one** wallet ledger, tagged `module: bus` | The never-sum-two-balances rule |
| 7 | Coupons carry `applicableTo: ["bus", …]` | One coupon sheet serves every module |
| 8 | `GET /users/bus-bookings/active` (or inclusion in `/activity/active`) | Floating active-job card |
| 9 | Support tickets accept `{ module: "bus", jobId }` | "Help with this booking" |
| 10 | Socket events namespaced `/bus` on the **same** connection, same token — *only if realtime is needed* | One connection, not a fifth |

---

## 19.16 Verification

Do not consider the module done until every box is ticked.

**Structural**
- [ ] `grep -rE "import .*modules/(food|taxi|parcel|rental)/" lib/modules/bus` → no output
- [ ] `grep -rE "import .*modules/" lib/shared lib/core lib/design_system` → no new output
- [ ] `dart analyze` clean; no new `riverpod_lint` warnings
- [ ] No `AppColors.` in the module (use `context.palette`)
- [ ] No direct `SharedPreferences` / `Hive` / `FlutterSecureStorage` / `permission_handler` / `Dio` imports
- [ ] Every route path starts with `/bus`
- [ ] Every `:id` route has a loader branch; no unguarded `state.extra` casts

**Functional**
- [ ] Hub tile appears, correct accent, opens `/bus`
- [ ] Full funnel works end to end, including payment and server-side verify
- [ ] Back from `/bus` returns to `/hub`, not out of the app
- [ ] Leaving mid-funnel and returning restores the draft
- [ ] Guest hits the auth gate at the right step and **returns to where they were**
- [ ] Module accent applies inside `/bus/*` and reverts outside it
- [ ] Feature flag off → tile hidden **and** `/bus/…` deep link 404s

**Integration**
- [ ] Booking appears in `/activity`, under All and under the Bus tab, in correct date order
- [ ] Upcoming booking shows the floating active-job card on `/hub`
- [ ] Wallet shows the debit, tagged Bus
- [ ] A coupon with `applicableTo: ["bus"]` applies; one scoped to food does not
- [ ] Push tested in **all three** app states — foreground, background, terminated — landing on the right screen
- [ ] Cold deep link `/bus/bookings/<id>` works from a killed app
- [ ] "Help with this booking" opens support chat with the right `ChatContext`
- [ ] Profile section appears in the right position

**Non-functional**
- [ ] DevTools: bus controllers **dispose** on module exit
- [ ] Memory stable after 10 entry/exit cycles
- [ ] `--trace-startup` unchanged — nothing bus-related runs before first frame
- [ ] `--analyze-size` delta matches the assets added
- [ ] Airplane-mode toggle mid-funnel recovers cleanly

---

## 19.17 Mistakes to avoid

Ranked by how often they happen and how expensive they are.

| # | Mistake | Cost | Symptom |
|---|---|---|---|
| 1 | Importing another module | Breaks the whole model | Lint error — heed it, don't suppress it |
| 2 | Un-namespaced routes (`/tickets` instead of `/bus/tickets`) | Silent | `go_router` registers the first match; no warning ever |
| 3 | Unconditional `state.extra as X` | Crash | Works in dev (warm push), crashes on push/deep-link/cold-start |
| 4 | Greedy `resolvePush` (returning non-null for unowned types) | Silent | Another module's notifications stop working |
| 5 | Not re-joining socket rooms in `onConnect` | Silent | Works until the first network blip, then goes deaf |
| 6 | Side effects in `build()` | Leak | Duplicate listeners/rooms per invalidation |
| 7 | `double` for money | Data | `₹349.99999`, mismatched totals |
| 8 | Trusting the payment gateway callback without server verify | **Financial** | Fraud surface |
| 9 | Caching mutable data (`seats`, `bookings`) | Data | Stale seat map sells an occupied seat |
| 10 | Re-implementing a design-system component | Drift | The module looks like a different app |
| 11 | Eager init in `warmUp` at app scope, or opening Hive boxes at boot | Startup | Cold start regresses for users who never open the module |
| 12 | Forgetting `module:` on `PaymentIntent` | Silent | Wallet entries and receipts unattributable |
| 13 | Bundling PNGs instead of WebP | Size | Download grows for everyone |
| 14 | Renaming `ModuleId.name` after release | **Irreversible** | Breaks live deep links, queued pushes, historical analytics |
| 15 | Adding a `ScreenUtilInit` inside the module | Layout | Wrong scale factors, silently |

---

## 19.18 Variations

### Module with sub-tabs (a food-shaped module)

If the module needs preserved per-tab state (browse → cart → back to browse keeping scroll position), use a `StatefulShellRoute.indexedStack` inside its own routes, as food does. Remember each branch stays alive — do not add tabs casually.

### Module that is a linear funnel (a taxi-shaped module)

No bottom nav. A funnel over a map or a form sequence, with the draft persisted. Bus is this shape.

### Module that only *extends* another

`pooling` sharing taxi's pickup/drop picker and tracking screen is **not** a module. Add it inside `modules/taxi` as a booking variant with its own repository and screens, sharing the controllers. You get all of taxi's plumbing for free and you avoid a cross-module import you would otherwise be forced into.

### Module as a separate Dart package

Once you have 6+ modules, or a module is built by a different team, promote it to `packages/module_bus/` with its own `pubspec.yaml` depending on `packages/superapp_core` and `packages/superapp_design_system`. The `AppModule` contract does not change — only the import paths do, and the boundary rule becomes enforced by the package manager instead of a lint. **Do not start here**; the extra ceremony is not worth it below ~6 modules.

---

## 19.19 Removing or disabling a module

Deleting is as important as adding, and the same contract makes it clean.

**Temporarily off (preferred):** set `module.bus: { enabled: false }` server-side. Tile hidden, routes 404, zero deploy. Do this first, always — it is the reversible option.

**Permanently:**
1. Remove `BusModule()` from `module_registry.dart` — the app immediately stops referencing anything in the folder
2. `rm -rf lib/modules/bus/` and `assets/images/bus/`
3. Remove the `ModuleId.bus` and `ModuleAccent.bus` enum entries
4. Remove the `bus_updates` push channel
5. Keep the routes as redirects to `/hub` for two releases, so live deep links and queued pushes land somewhere sensible rather than on "Page not found"
6. Leave historical `ActivityItem`s with `module: bus` renderable via the generic row — **users' past bookings must not vanish from their history because you removed a product**

Point 6 is the one that gets forgotten, and it is the one users notice.
