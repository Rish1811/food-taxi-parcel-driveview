# Chapter 2 — Target Flutter Architecture

The tree, the rules that keep it honest, and the `AppModule` contract that makes a module pluggable instead of hand-wired.

---

## 2.1 The four tiers

```
┌──────────────────────────────────────────────────────────────────┐
│  modules/     food · taxi · parcel · rental                      │
│               a vertical product. owns its screens, controllers, │
│               models, endpoints, routes, socket events, pushes.  │
│  may import:  shared/  design_system/  core/                     │
│  must NOT:    import another module. ever.                       │
└──────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────┐
│  shared/      auth · profile · wallet · address · activity ·     │
│               search · notifications · support · payment ·       │
│               referral · offers · settings · session             │
│               cross-module FEATURES. one user, one wallet,        │
│               one history — regardless of which module wrote it.  │
│  may import:  design_system/  core/                              │
│  must NOT:    import modules/                                    │
└──────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────┐
│  design_system/  tokens · theme · components                     │
│                  every pixel primitive. no business logic,        │
│                  no network, no providers that fetch.             │
│  may import:     core/utils + core/config only                   │
└──────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────┐
│  core/        network · realtime · push · storage · location ·   │
│               maps · payment · permissions · error · config      │
│               platform integration. ZERO feature knowledge —      │
│               core must not know the word "restaurant" or "ride". │
│  may import:  nothing above it                                    │
└──────────────────────────────────────────────────────────────────┘
```

**Why four tiers and not three.** The reflex is `core / features / shared`. That fails here for one specific reason: "shared" then has to hold both `PrimaryButton` and `WalletRepository`, and those have completely different dependency rules. A button must be importable from anywhere including `core`'s error screens; a wallet repository must not be. Splitting `design_system` out of `shared` is what makes the import rule enforceable by a linter.

**The rule that actually matters.** `modules/food/**` must never contain `import '../taxi/…'`. The moment one module imports another, you no longer have a super app — you have one app with confusing folder names. Everything a module needs from another module goes through `shared/` or through the registry. Enforcement in §2.9.

---

## 2.2 The full tree

```
lib/
├── main.dart                                 ~20 lines. nothing but bootstrap+runApp
├── bootstrap.dart                            phased init; see §2.6
│
├── app/
│   ├── super_app.dart                        MaterialApp.router root
│   ├── app_shell.dart                        global chrome: offline banner, session
│   │                                         watcher, active-job cards
│   ├── hub/
│   │   ├── hub_screen.dart                   the super-app home / module launcher
│   │   ├── hub_controller.dart               reads server module list + entitlements
│   │   └── widgets/module_tile.dart
│   └── di/
│       ├── boot_overrides.dart               ProviderScope overrides built at boot
│       └── app_providers.dart                app-scope providers (router, registry)
│
├── core/
│   ├── config/
│   │   ├── env.dart                          ★ every dart-define in one place
│   │   ├── backend_endpoint.dart             (id, baseUrl, socketUrl, authScheme)
│   │   ├── flavors.dart                      dev / staging / prod
│   │   └── feature_flags.dart                remote + local flags
│   ├── network/
│   │   ├── api_client.dart                   ← food's 354-line client, + baseUrl param
│   │   ├── api_client_registry.dart          endpointId → ApiClient  (multi-backend)
│   │   ├── api_envelope.dart                 {success,message,data} unwrap
│   │   ├── api_response.dart
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart
│   │       ├── cache_interceptor.dart        ← food's disk-backed GET cache
│   │       ├── log_interceptor.dart
│   │       └── retry_interceptor.dart
│   ├── error/
│   │   ├── failure.dart                      ← food's typed hierarchy
│   │   ├── error_mapper.dart                 DioException → Failure
│   │   └── error_reporter.dart
│   ├── realtime/
│   │   ├── socket_gateway.dart               ★ owns N connections; see §2.7
│   │   ├── socket_channel.dart               one connection: reconnect, room replay
│   │   ├── socket_binding.dart               what a module subscribes to
│   │   └── socket_lifecycle.dart             login/logout/foreground/background
│   ├── push/
│   │   ├── push_service.dart                 ← food's 457-line service, generalised
│   │   ├── push_message.dart                 ★ unified envelope; see §2.8
│   │   ├── push_router.dart                  PushMessage → route, via registry
│   │   ├── push_channels.dart                Android channel definitions
│   │   └── push_background_handler.dart      @pragma('vm:entry-point')
│   ├── storage/
│   │   ├── token_storage.dart                ← food's secure pair + taxi's aOptions
│   │   ├── kv_store.dart                     SharedPreferences facade
│   │   ├── box_store.dart                    Hive facade (taxi's 5 boxes)
│   │   └── cache_store.dart                  TTL cache used by the interceptor
│   ├── location/
│   │   ├── location_service.dart             GPS + permission (food's result shape)
│   │   ├── geocoding_service.dart            reverse geocode, REST
│   │   ├── geocode_cache.dart                ← taxi's grid + throttle + skip
│   │   └── place_search_service.dart         autocomplete
│   ├── maps/
│   │   ├── map_style.dart                    ← taxi's app_map_style (157 lines)
│   │   ├── marker_factory.dart               ← taxi's marker_icon_loader + vehicle icons
│   │   ├── polyline_service.dart             ← taxi's decoder + route service
│   │   ├── map_camera.dart                   fit-bounds, follow, smooth animate
│   │   └── live_track_controller.dart        shared "someone is moving toward you"
│   ├── payment/
│   │   ├── payment_gateway.dart              ← food's 272-line Razorpay
│   │   ├── payment_intent.dart               amount, purpose, moduleId, metadata
│   │   └── adapters/{razorpay,phonepe,wallet}_adapter.dart
│   ├── permissions/
│   │   └── permission_service.dart           one place that touches permission_handler
│   ├── connectivity/
│   │   └── connectivity_service.dart         connectivity_plus (replaces food's poll)
│   ├── media/
│   │   ├── image_picker_service.dart
│   │   └── image_upload_service.dart
│   ├── audio/
│   │   └── audio_service.dart                ← taxi's + food's 2 audio players merged
│   ├── speech/
│   │   └── speech_service.dart               ← food's, used by unified search
│   ├── logging/
│   │   └── app_logger.dart
│   └── utils/
│       ├── formatters.dart  validators.dart  haptics.dart
│       ├── money.dart  distance.dart  duration.dart
│       ├── debounce.dart  result.dart  json.dart
│       └── deep_link_parser.dart
│
├── design_system/
│   ├── tokens/
│   │   ├── color_tokens.dart                 semantic, NOT brand-specific
│   │   ├── module_accent.dart                ★ per-module brand colour
│   │   ├── spacing.dart  radius.dart  elevation.dart  motion.dart
│   │   └── typography.dart
│   ├── theme/
│   │   ├── app_theme.dart                    buildLight/buildDark(accent)
│   │   ├── app_theme_extension.dart          ★ replaces mutable AppColors statics
│   │   └── theme_controller.dart             mode + accent + user colour choice
│   └── components/
│       ├── buttons/     primary · secondary · text · icon · fab
│       ├── inputs/      text_field · search_field · otp_field · phone_field
│       ├── feedback/    snackbar · toast · dialog · confirm · banner · offline
│       ├── skeletons/   shimmer_box · list_skeleton · card_skeleton
│       ├── layout/      app_bar · bottom_sheet · section_title · scaffold
│       ├── cards/       info_card · price_card · profile_tile · stat_tile
│       ├── media/       smart_image · avatar · empty_state
│       ├── nav/         bottom_nav · segmented_tabs
│       └── indicators/  rating_stars · badge · chip · step_indicator
│
├── shared/
│   ├── session/                               ★ owns "who is logged in, is the app usable"
│   │   ├── application/  session_controller · session_state · force_logout_watcher
│   │   └── presentation/  splash · onboarding · no_internet · maintenance ·
│   │                      force_update · server_error · gps_disabled ·
│   │                      location_denied · session_expired   ← taxi's misc/
│   ├── auth/
│   │   ├── data/        auth_repository · auth_api · session_dto
│   │   ├── application/ auth_controller · auth_state · otp_controller
│   │   └── presentation/ phone_entry · otp · profile_setup · permission_gates
│   ├── profile/
│   │   ├── data/        user_repository · user_dto  (core identity only)
│   │   ├── application/ profile_controller
│   │   └── presentation/ profile_screen (composed of module sections) · edit_profile
│   ├── wallet/          data · application · presentation   ← §14
│   ├── address/         data · application · presentation   ← one address book
│   ├── activity/        data · application · presentation   ← §15 unified history
│   ├── search/          data · application · presentation   ← §13 unified search
│   ├── notifications/   data · application · presentation   ← inbox + settings
│   ├── support/         data · application · presentation   ← tickets · chat · SOS
│   ├── payment/         application · presentation          ← method picker, sheets
│   ├── referral/        data · application · presentation
│   ├── offers/          data · application · presentation   ← coupons across modules
│   └── settings/        application · presentation          ← theme · language · security
│
├── modules/
│   ├── app_module.dart                        ★ the contract; §2.4
│   ├── module_registry.dart                   ★ the only place modules are listed
│   ├── module_id.dart
│   │
│   ├── food/
│   │   ├── food_module.dart                   implements AppModule
│   │   ├── food_routes.dart
│   │   ├── api/
│   │   │   ├── food_endpoints.dart             ← ApiPaths /food/*
│   │   │   └── datasources/  catalog · order · cart · favorites · store99 · zone
│   │   ├── data/
│   │   │   ├── models/  restaurant · food · variant · category · order ·
│   │   │   │            order_pricing · cart_item · promo_banner · store99 …
│   │   │   └── repositories/  restaurant · order · cart · favorites · store99
│   │   ├── application/
│   │   │   ├── home_controller · restaurant_controller · cart_controller ·
│   │   │   │  checkout_controller · order_tracking_controller · store99_controller
│   │   │   └── food_providers.dart
│   │   └── presentation/
│   │       ├── home/  restaurant/  food_detail/  cart/  checkout/
│   │       ├── orders/  store99/  favorites/  offers/
│   │       └── widgets/
│   │
│   ├── taxi/
│   │   ├── taxi_module.dart
│   │   ├── taxi_routes.dart
│   │   ├── api/     taxi_endpoints (/rides/*, /users/vehicle-types …)
│   │   ├── data/    models: ride · vehicle_type · set_price · ride_message
│   │   │            repositories: ride · booking · fare
│   │   ├── application/  booking_controller · ride_search_controller ·
│   │   │                 ride_tracking_controller · fare_calculator ·
│   │   │                 ride_history_controller
│   │   └── presentation/  booking/  tracking/  history/  rating/  widgets/
│   │
│   ├── parcel/                                ← taxi's features/delivery/
│   │   ├── parcel_module.dart · parcel_routes.dart
│   │   ├── api/  data/  application/  presentation/
│   │
│   └── rental/                                ← taxi's features/rental/
│       ├── rental_module.dart · rental_routes.dart
│       ├── api/  data/  application/  presentation/
│
├── l10n/                                      app_en.arb, app_hi.arb, …
└── generated/                                 gen-l10n output (git-ignored)
```

---

## 2.3 Every folder, and why it exists

### `main.dart`
Twenty lines. `WidgetsFlutterBinding.ensureInitialized()`, `await bootstrap()`, `runApp(ProviderScope(overrides: …, child: SuperApp()))`. Nothing else. Today food's `main.dart` does Firebase init and background-handler registration, and taxi's does Hive + secure storage + Firebase. Both belong in `bootstrap.dart` so that startup order is one readable list instead of two.

### `bootstrap.dart`
The phased startup sequence (§2.6). This is where the app-size and cold-start wins in Chapter 16 come from: today, merging naively means Hive + Firebase + RTDB + sockets + push + maps all initialise before the first frame.

### `app/`
The composition root. `super_app.dart` builds `MaterialApp.router`. `app_shell.dart` is the global chrome that must survive module switches — offline banner, session-expiry watcher, and the "you have an active job" floating card (food already has `FloatingActiveOrderCard`; taxi needs the same for an in-progress ride). `app/hub/` is the super-app landing screen.

**`app/` may import everything. Nothing may import `app/`.** It is the top of the graph.

### `core/config/env.dart`
One file holding every `String.fromEnvironment`. Food already does this correctly (`API_HOST`, `API_BASE_URL`, `SOCKET_URL`, `BRAND_LOGO_URL`); taxi hardcodes `https://taxi.appzeto.com/api/v1` as a `const`. Consolidating means a staging build is a `--dart-define` list, not a diff.

### `core/config/backend_endpoint.dart` — the multi-backend seam
This is the single most important file for the transition period:

```dart
class BackendEndpoint {
  final String id;            // 'food' | 'taxi' | 'unified'
  final String baseUrl;
  final String socketUrl;
  final AuthScheme authScheme; // bearerWithRefresh | bearerOnly
}
```

Every module declares which endpoint it talks to. Today: food → `suvio.appzeto.com`, taxi/parcel/rental → `taxi.appzeto.com`. After the backend merge: all four point at `unified`, and **not one line of module code changes**. That property is why the whole architecture is shaped this way.

### `core/network/api_client_registry.dart`
`ApiClient` is currently a singleton bound to one base URL. It becomes keyed:

```dart
final apiClientProvider = Provider.family<ApiClient, String>((ref, endpointId) { … });
```

One `Dio`, one cache, one refresh single-flight **per endpoint**. Sharing a single `Dio` across two hosts would mean one host's 401 triggering a refresh against the other — a real bug that would be very hard to trace.

### `core/realtime/`
Detailed in §2.7. `SocketGateway` owns connections; `SocketChannel` is one connection with taxi's reconnect-and-replay logic; `SocketBinding` is what a module declares it needs.

### `core/push/`
Detailed in §2.8. Food's `PushService` almost fits already — its one coupling to food is `PushDeepLink.isOrderEvent` hardcoding `order_`/`delivery_`/`payment_success` prefixes. That knowledge moves into `FoodModule.resolvePush()`.

### `core/storage/`
Three facades so that no feature imports `SharedPreferences`, `Hive`, or `FlutterSecureStorage` directly. Today food touches `SharedPreferences` in 5 files (including inside the network cache interceptor) and taxi touches Hive boxes from providers. A facade means changing the storage engine is one file, and it makes "clear everything on logout" a single auditable call.

### `core/maps/`
Taxi's map toolkit, promoted. Food's `live_tracking_map.dart` (894 lines) reimplements marker rotation and polyline drawing that taxi already has as utilities. `live_track_controller.dart` is the shared abstraction: "an entity is moving from A to B, animate it, keep the camera sensible" — that is food's delivery rider and taxi's driver and parcel's captain, identically.

### `core/audio/`
Small but worth naming: food has **two** near-identical audio players (`referral_audio_player.dart` 75, `refresh_audio_player.dart` 62) and taxi has `audio_service.dart` (42) for trip-start/ride-end cues. One service, three sounds.

### `design_system/tokens/module_accent.dart`
Per-module brand colour, which is how the super app stays visually coherent while food feels like food and taxi feels like taxi:

```dart
enum ModuleAccent {
  food(Color(0xFFFF7A00)),   // Suvio orange
  taxi(Color(0xFFFF5C2B)),   // UdanX orange
  parcel(Color(0xFFF59E0B)),
  rental(Color(0xFF3B82F6)),
  hub(Color(0xFFFF7A00));
}
```

Note both existing brands are orange but **different** oranges. That is a decision for the product owner, not the architecture — the architecture just needs to be able to express either answer.

### `design_system/theme/app_theme_extension.dart` — the replacement for mutable statics
Today food repaints 1,125 `AppColors.primary` read sites by reassigning a mutable static and rebuilding `MaterialApp`. That works, but it (a) rebuilds the entire tree for a colour change, and (b) is incompatible with taxi's 55 `const AppColors.primary` uses.

Target: a `ThemeExtension<AppPalette>` carried in `ThemeData`, read as `context.palette.primary`. A module-scoped `Theme` override then makes entering `/taxi` re-accent the subtree without touching the root. Migration path in [05 §6.11](05-shared-components.md).

### `shared/session/`
The tier both apps are missing pieces of. Food has none of the system screens; taxi has 8 but no session controller (its `_AppBootstrapper` and `DioClient.onUnauthorized` are wired loosely). `SessionController` owns: is there a token, is it valid, has the server force-logged-us-out, is the app under maintenance, is an update mandatory. Everything else reacts to it.

### `shared/*` generally
Each is `data/` + `application/` + `presentation/`, the same shape as a module — because a shared feature *is* a feature, it just has no module of its own. The distinction is dependency direction: `shared/wallet` knows nothing about restaurants or rides; it consumes `WalletSource`s that modules contribute.

### `modules/*`
Four vertical slices, each self-contained, each behind one contract file. `api/` holds the endpoint constants and datasources — deliberately co-located with the module rather than in `core`, because "which URL does the ride endpoint live at" is module knowledge, not platform knowledge. Food's current `ApiPaths` (102 lines, all `/food/*`) splits cleanly; taxi's `ApiConstants` (110 lines) splits across taxi / parcel / rental / shared.

---

## 2.4 The `AppModule` contract

This is the answer to "how do we integrate the module". Every cross-cutting system in the app — routing, push routing, sockets, history, search, DI, warm-up — needs a per-module contribution. Without a contract, each of those becomes a `switch (moduleId)` somewhere in `app/`, and adding a fifth module means editing seven files. With a contract, adding a module means writing one file and adding one line to the registry.

```dart
// modules/app_module.dart

abstract interface class AppModule {
  /// Stable identity. Used as a route prefix, a push discriminator,
  /// an activity-source tag, and an analytics dimension.
  ModuleId get id;

  /// Hub tile presentation.
  String get label;
  String get iconAsset;
  ModuleAccent get accent;

  /// Which backend this module talks to. During the transition,
  /// food and taxi return different endpoints; after the merge,
  /// all four return the same one.
  String get endpointId;

  /// Where the hub sends the user. Always the module's own namespace.
  String get entryRoute;               // '/food' | '/taxi' | '/parcel' | '/rental'

  /// Route subtree, already namespaced under entryRoute.
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey);

  /// Module-scoped provider overrides, installed when the module
  /// is entered and torn down when it is left (§2.5).
  List<Override> providerOverrides();

  /// Push routing: given a unified message, does this module claim it,
  /// and if so where does it go? Returns null to decline.
  PushRoute? resolvePush(PushMessage message);

  /// Realtime: which events on which endpoint, and what to do with them.
  /// Null means the module needs no socket.
  SocketBinding? socketBinding();

  /// Contributions to the unified Activity page (§15).
  List<ActivitySource> activitySources();

  /// Contributions to unified search (§13). Empty list = not searchable.
  List<SearchSource> searchSources();

  /// Sections this module adds to the shared Profile screen
  /// (e.g. food adds "Favourites"; taxi adds "Emergency contacts").
  List<ProfileSection> profileSections();

  /// Wallet transaction sources this module contributes (§14, read-only).
  List<WalletHistorySource> walletHistorySources();

  /// One-time expensive setup, deferred until the module is first entered.
  /// Maps SDK warm-up, module socket join, catalogue prefetch.
  Future<void> warmUp(Ref ref);

  /// Called when the user leaves the module and it is safe to release
  /// heavy resources (map controllers, image caches, socket rooms).
  Future<void> cooldown(Ref ref);

  /// Server-driven availability. The hub hides modules that are off,
  /// and the router refuses their routes.
  bool isEnabled(FeatureFlags flags);
}
```

### `modules/module_registry.dart`

```dart
final moduleRegistryProvider = Provider<ModuleRegistry>((ref) => ModuleRegistry(const [
  FoodModule(),
  TaxiModule(),
  ParcelModule(),
  RentalModule(),
]));

class ModuleRegistry {
  final List<AppModule> modules;
  const ModuleRegistry(this.modules);

  AppModule? byId(ModuleId id);
  List<RouteBase> allRoutes(GlobalKey<NavigatorState> k);
  PushRoute? resolvePush(PushMessage m);          // first non-null wins
  List<SocketBinding> allSocketBindings();
  List<ActivitySource> allActivitySources();
  List<SearchSource> allSearchSources();
  List<AppModule> enabled(FeatureFlags f);
}
```

**One file to add a module.** That is the test of whether this architecture is real. Adding `bus` (whose endpoints already exist in taxi's `api_constants.dart`) means: write `modules/bus/bus_module.dart`, add `BusModule()` to that list. Routing, push routing, activity feed, search, hub tile, and DI all pick it up.

### Example implementation sketch

```dart
// modules/food/food_module.dart
class FoodModule implements AppModule {
  const FoodModule();

  @override ModuleId get id => ModuleId.food;
  @override String get label => 'Food';
  @override ModuleAccent get accent => ModuleAccent.food;
  @override String get endpointId => BackendIds.food;   // → 'unified' post-merge
  @override String get entryRoute => '/food';

  @override
  List<RouteBase> routes(k) => foodRoutes(k);           // food_routes.dart

  @override
  PushRoute? resolvePush(PushMessage m) {
    if (m.module != null && m.module != ModuleId.food) return null;
    final id = m.string('orderMongoId') ?? m.string('orderId');
    return switch (m.type) {
      'order_created' || 'order_accepted' || 'order_out_for_delivery'
        when id != null => PushRoute('/food/orders/track/$id'),
      'order_delivered'  when id != null => PushRoute('/food/orders/delivered/$id'),
      'payment_success'  when id != null => PushRoute('/food/orders/success/$id'),
      _ => null,
    };
  }

  @override
  SocketBinding? socketBinding() => SocketBinding(
    endpointId: endpointId,
    events: const {
      'order_status_update', 'order_ready',
      'location-update', 'delivery_drop_otp',
      'chat:message', 'chat:typing',
    },
    onConnect: (s, ref) => ref.read(foodTrackedOrdersProvider)
        .forEach((id) => s.emit('join-tracking', id)),
  );

  @override
  List<ActivitySource> activitySources() => const [FoodOrderActivitySource()];

  @override
  List<SearchSource> searchSources() => const [
    RestaurantSearchSource(), DishSearchSource(),
  ];

  @override
  Future<void> warmUp(Ref ref) async {
    await ref.read(foodZoneControllerProvider.notifier).detect();
    ref.read(foodCatalogPrefetchProvider);   // fire and forget
  }
}
```

Compare that with the alternative: `push_router.dart` containing an if-chain over food *and* taxi *and* parcel *and* rental type strings, which is exactly what both apps do today in `_handleDeepLink` and `onMessageOpened`.

---

## 2.5 Module-scoped dependency injection

Riverpod's `ProviderScope` nesting is what makes module DI real. The module's route subtree is wrapped:

```dart
ShellRoute(
  builder: (context, state, child) => ProviderScope(
    overrides: FoodModule().providerOverrides(),
    child: ModuleTheme(accent: ModuleAccent.food, child: child),
  ),
  routes: [ /* every /food/* route */ ],
)
```

Three things follow:

1. **Module controllers are disposed when the user leaves the module.** Today, food's cart controller and taxi's booking controller would both live forever in one root scope. With scoping, `autoDispose` actually fires, which is the difference between a super app that holds 90 MB and one that holds 250 MB after twenty minutes of browsing.
2. **Two modules can hold same-named providers** without colliding, because each resolves inside its own scope.
3. **Module theming is a subtree override**, not a global mutation — which is what kills the mutable `AppColors.primary` problem.

Exception: state that must survive leaving the module goes in `shared/`. An in-progress food order and an in-progress ride must both keep tracking while the user browses elsewhere, so `shared/activity/application/active_jobs_controller.dart` lives at app scope and modules feed it. `app_shell.dart` renders the floating cards from it.

---

## 2.6 Bootstrap sequencing

Today's startup, if you merged naively:

```
Hive.initFlutter + 5 boxes  →  SecureStorage  →  Firebase.initializeApp
→  FCM background handler   →  permission prompts  →  getToken → POST to backend
→  socket connect ×2        →  RTDB subscribe   →  first frame
```

That is a cold start where a large fraction of the work is for features the user has not opened. Target:

```dart
// bootstrap.dart
Future<BootResult> bootstrap() async {
  // ── Tier 0: blocking, must precede the first frame ────────────────
  final kv        = await KvStore.open();          // SharedPreferences
  final secure    = TokenStorage();                // lazy reads, no I/O yet
  final flags     = FeatureFlags.fromCache(kv);    // cached, refreshed later
  final themeMode = kv.themeMode();                // avoids a light→dark flash

  // ── Tier 1: parallel, still before first frame, all failure-tolerant ──
  await Future.wait([
    Firebase.initializeApp().catchError(_report),  // FCM + RTDB need it
    ConnectivityService.instance.start(),
  ]);
  PushService.registerBackgroundHandler();          // cheap, must be early

  // ── Tier 2: after first frame (addPostFrameCallback) ──────────────
  //   push permission + token registration        ← food does this already
  //   session restore (GET /me)                   ← drives splash → hub
  //   feature-flag refresh
  //   socket connect, only if logged in

  // ── Tier 3: on first module entry — AppModule.warmUp() ────────────
  //   Hive boxes: only the ones that module needs
  //   Maps SDK warm-up
  //   catalogue / vehicle-type prefetch
  //   module socket room join
  return BootResult(kv: kv, secure: secure, flags: flags, themeMode: themeMode);
}
```

Two specific wins over the current code:
- **Hive moves out of Tier 0.** Taxi opens 5 boxes before `runApp`. Only `settings` is needed that early; `recentSearches`, `savedAddresses`, `emergencyContacts`, `favoriteDrivers` are Tier 3.
- **Notification permission moves off the critical path.** Both apps currently prompt on first frame. In a super app, prompting for notifications before the user has chosen a service is both slower and worse UX — ask when they first book something.

---

## 2.7 Realtime architecture

```
                       SocketGateway  (app scope, one instance)
                              │
       ┌──────────────────────┼──────────────────────┐
       ▼                      ▼                      ▼
  SocketChannel          SocketChannel         SocketChannel
  endpointId:'food'      endpointId:'taxi'     endpointId:'unified'
  suvio.appzeto.com      taxi.appzeto.com      (post-merge; the other
       │                      │                 two collapse into this)
       │                      │
  ┌────┴────┐          ┌──────┴──────┐
  ▼         ▼          ▼             ▼
FoodModule  shared/  TaxiModule  ParcelModule
binding     support   binding     binding
```

`SocketChannel` responsibilities, taken from the better half of each existing implementation:

| Behaviour | Source |
|---|---|
| Handler registry replayed on every (re)connect | Taxi (`_pendingHandlers`) |
| `addConnectionListener` so rooms are re-joined after a blip | Taxi |
| Room set re-emitted on connect **and** reconnect | Food (`_trackedOrderIds`) |
| `polling` before `websocket` transport order | Food — deliberate: some networks block the WS upgrade handshake |
| Unbounded reconnection attempts with backoff caps | Food (`1<<30`, 2 s → 10 s) |
| Dispose the old socket before replacing it | Taxi — a dead-but-non-null socket keeps its timers and leaks one per reconnect |
| Never throws upward; sockets are an optimisation over polling | Food (explicit design note) |
| Typed broadcast streams per concern | Food (`orderEvents`, `chatMessages`, `chatTyping`) |

`SocketBinding` is the module's declaration:

```dart
class SocketBinding {
  final String endpointId;
  final Set<String> events;
  final String? namespace;                        // post-merge: '/food', '/taxi'
  final void Function(SocketChannel, Ref) onConnect;
  final void Function(String event, dynamic data, Ref) onEvent;
}
```

`SocketLifecycle` centralises what both apps do ad hoc: connect on login, disconnect on logout, and — new — **disconnect on background after a grace period, reconnect on foreground**. Neither app does the background part today, which on a super app with two live connections is a measurable battery cost.

---

## 2.8 Notification architecture

One envelope, one parser, per-module resolvers.

```dart
class PushMessage {
  final ModuleId? module;      // from data['module'] — REQUEST B4
  final String type;           // data['type']
  final Map<String, dynamic> data;
  final String? title, body;
  final PushOrigin origin;     // foreground | background | terminated

  String? string(String key);
  double? number(String key);
}
```

```
FCM  →  PushService  →  PushMessage  →  PushRouter  →  ModuleRegistry.resolvePush()
                             │                              │
                             │                    first module to claim it wins
                             ▼                              ▼
                    channel selection                  PushRoute('/food/orders/track/x')
                    (per module, §11)                        │
                                                             ▼
                                              router.push()  — via provider,
                                              never a raw navigatorKey
```

Why this shape:

- Today food's `PushDeepLink.isOrderEvent` hardcodes `order_` / `delivery_` / `payment_success` prefixes, and taxi's `onMessageOpened` hardcodes `no_drivers_found` and `rideId`. Both would need editing every time a module is added.
- **`data['module']` is request B4.** Without it the router must guess from `type` prefixes, and food's `delivery_` prefix (food delivery) collides semantically with the parcel module's deliveries — a genuinely ambiguous case that a discriminator resolves for free.
- The Android **channel** is per module (`food_orders`, `ride_updates`, `parcel_updates`) so users can mute ride offers without muting order-delivered. Today the two apps have exactly one channel each (`high_importance_channel`, `ride_updates`) and the manifest can only declare one default — see [08 §11](08-api-socket-push.md).

---

## 2.9 Enforcing the boundaries

Rules that are not machine-checked are suggestions. Add to `analysis_options.yaml`:

```yaml
analyzer:
  errors:
    depend_on_referenced_packages: error
  plugins:
    - custom_lint

custom_lint:
  rules:
    - no_cross_module_imports        # modules/food/** may not import modules/taxi/**
    - no_module_imports_in_shared    # shared/** may not import modules/**
    - no_feature_imports_in_core     # core/** may not import shared/** or modules/**
    - design_system_purity           # design_system/** may not import network/storage
```

Cheaper interim version, in CI, before writing lint rules:

```bash
# a module importing another module
! grep -rE "import .*modules/(food|taxi|parcel|rental)/" lib/modules \
  | grep -v "modules/\1/"
# shared reaching into modules
! grep -rE "import .*modules/" lib/shared
# core reaching upward
! grep -rE "import .*(shared|modules|design_system)/" lib/core
```

Three grep lines in CI will catch 95 % of the drift, and they cost nothing to add on day one. Add them in Phase 3, before there is anything to violate them.

---

## 2.10 What this architecture buys, concretely

| Problem today | Handled by |
|---|---|
| 20 colliding class names | Module namespacing; each module owns its own `Order`/`User` view |
| 9 colliding routes | Route prefixes + registry-owned route assembly (§7) |
| Two backends, one app | `BackendEndpoint` + keyed `ApiClient`; unification is config |
| Two sockets, two auth tokens | `SocketGateway` with per-endpoint channels |
| Two push parsers | `PushMessage` + `resolvePush()` per module |
| Everything initialises at boot | Tiered `bootstrap()` + `AppModule.warmUp()` |
| Controllers never dispose | Module-scoped `ProviderScope` |
| Mutable colour statics rebuild the world | `ThemeExtension` + subtree `ModuleTheme` |
| Four history screens | `ActivitySource` contributions → one Activity page |
| Two search screens | `SearchSource` contributions → one search entry |
| Adding a 5th module (bus/pooling, already in the API) | One file + one registry line |
