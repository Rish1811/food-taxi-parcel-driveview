# Chapter 8 — State Management and Dependency Injection

Riverpod 2 → 3, provider scoping, controller ownership, and the six global-name collisions.

---

## 8.1 Measured state

| | Food | Taxi |
|---|---|---|
| `flutter_riverpod` | **3.3.2** | **2.6.1** |
| `extends Notifier` | **23 files** | 0 |
| `AsyncNotifier` | **3 files** | 0 |
| `NotifierProvider` | **26 files** | 0 (the 11 matches are `StateNotifierProvider` substrings) |
| `StateNotifier` | **0** | **12 files** |
| `StateNotifierProvider` | **0** | **11 files** |
| `FutureProvider` | 8 files | 10 files |
| `StreamProvider` | 0 | 2 files |
| `StateProvider` | 0 | 0 |
| `ChangeNotifier` | 0 | 0 |
| `ConsumerWidget` | 14 | 22 |
| `ConsumerStatefulWidget` | 34 | 36 |
| Top-level provider globals | **75** | **60** |
| DI organisation | `src/di/` — 16 files, one per concern | `core/providers/core_providers.dart` (51 lines) + per-feature `*_providers.dart` |

Food is a clean Riverpod 3 codebase. Taxi is a clean Riverpod 2 codebase. Neither uses code generation (`riverpod_generator`), which is fortunate — it removes a whole category of migration pain.

---

## 8.2 The six colliding global names

Riverpod providers are top-level `final` variables. Two files declaring `apiClientProvider` in one library graph is a compile error unless aliased, and aliasing 135 globals is not a plan.

| Global | Food | Taxi | Resolution |
|---|---|---|---|
| `apiClientProvider` | `di/network_providers.dart` — `Provider<ApiClient>` | `core/providers/core_providers.dart` — `Provider<ApiClient>` | **One**, becomes `Provider.family<ApiClient, String>` keyed by `endpointId` |
| `authRepositoryProvider` | `di/auth_providers.dart` | `features/auth/application/auth_providers.dart` | **One** in `shared/auth` (gated on B1/B2) |
| `locationServiceProvider` | `di/location_providers.dart` | `core/providers/core_providers.dart` | **One** in `core/location` |
| `socketServiceProvider` | `di/socket_providers.dart` | `core/providers/core_providers.dart` | Replaced by `socketGatewayProvider` + `socketChannelProvider.family` |
| `walletRepositoryProvider` | `di/wallet_providers.dart` | `features/wallet/application/wallet_providers.dart` | **One** in `shared/wallet` (gated on B6) |
| `rootNavigatorKey` | `presentation/navigation/app_router.dart` | `core/navigation/navigator_key.dart` | **One** in `app/di/app_providers.dart` |

Beyond exact collisions, both apps use the same *naming* for different things — `themeProvider` (food) vs `themeModeProvider` (taxi), `authViewModelProvider` (food) vs `authControllerProvider` (taxi). Not compile errors, but confusing enough to be worth normalising in the same pass.

### Naming convention for the merged app

```
<thing>Provider              services & repositories   apiClientProvider
<feature>ControllerProvider  Notifiers                 cartControllerProvider
<feature>StateProvider       derived read-only slices   cartTotalProvider
```

Food's `*ViewModel` naming (17 files) and taxi's `*Controller` naming (9 files) both exist. **Standardise on `Controller`** — it matches taxi, matches Riverpod's own docs, and "view model" is misleading for a `Notifier` that outlives any view. That is 17 renames in food, all mechanical.

---

## 8.3 Riverpod 2 → 3: the 12 files

The full list, with what each one needs:

| File | Lines | Notifier type | Migration note |
|---|---|---|---|
| `features/home/application/booking_controller.dart` | 239 | `StateNotifier<BookingState>` | Largest. Holds the booking funnel; check constructor side effects |
| `features/home/application/ride_search_controller.dart` | 216 | `StateNotifier<RideSearchState>` | Debounced place search; timer must move to `ref.onDispose` |
| `features/ride/application/ride_tracking_controller.dart` | 263 | `StateNotifier<RideTrackingState>` | **Joins a socket room in its constructor** — the riskiest one |
| `features/ride/application/ride_history_controller.dart` | 69 | `StateNotifier<RideHistoryState>` | Being replaced by `ActivitySource` anyway |
| `features/delivery/application/delivery_booking_controller.dart` | 260 | `StateNotifier` | Parcel funnel |
| `features/auth/application/auth_controller.dart` | 139 | `StateNotifier<AuthState>` | Being merged into `shared/auth` |
| `features/profile/application/locale_provider.dart` | 29 | `StateNotifier<String>` | Reads Hive in constructor → `build()` |
| `features/profile/application/emergency_contacts_provider.dart` | 38 | `StateNotifier<List<…>>` | Hive-backed |
| `features/home/application/saved_places_provider.dart` | 80 | `StateNotifier` | Being merged into `shared/address` |
| `features/home/application/recent_searches_provider.dart` | 40 | `StateNotifier` | Being merged into `shared/search` |
| `core/providers/theme_provider.dart` | 41 | `StateNotifier<ThemeMode>` | Being merged into `theme_controller` |
| `features/subscription/application/subscription_providers.dart` | 16 | `StateNotifierProvider` | Small |

**Six of the twelve are being merged or replaced anyway** (`ride_history`, `auth`, `saved_places`, `recent_searches`, `theme`, and partly `locale`), so they get rewritten as part of the shared collapse rather than migrated twice. That leaves **six genuine migrations**: `booking_controller`, `ride_search_controller`, `ride_tracking_controller`, `delivery_booking_controller`, `emergency_contacts_provider`, `subscription_providers` — about 800 lines.

### The mechanical transformation

```dart
// ── Riverpod 2 (taxi today) ────────────────────────────────────────
class LocaleNotifier extends StateNotifier<String> {
  final Ref ref;
  LocaleNotifier(this.ref) : super('en') {
    final box = ref.read(localStorageServiceProvider).settings;
    state = (box.get(StorageKeys.localeCode) as String?) ?? 'en';
  }
  void setLocale(String code) {
    state = code;
    ref.read(localStorageServiceProvider).settings.put(StorageKeys.localeCode, code);
  }
}
final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) => LocaleNotifier(ref));

// ── Riverpod 3 (food's idiom) ──────────────────────────────────────
class LocaleController extends Notifier<String> {
  @override
  String build() => ref.read(kvStoreProvider).localeCode ?? 'en';   // init moves here

  void setLocale(String code) {
    state = code;
    ref.read(kvStoreProvider).setLocaleCode(code);
  }
}
final localeProvider = NotifierProvider<LocaleController, String>(LocaleController.new);
```

Four mechanical changes:
1. `extends StateNotifier<T>` → `extends Notifier<T>`
2. constructor + `super(initial)` → `@override T build()` returning the initial value
3. injected `Ref ref` field → inherited `ref`
4. `StateNotifierProvider<N, T>((ref) => N(ref))` → `NotifierProvider<N, T>(N.new)`

### The non-mechanical part — read this before starting

**`build()` re-runs on every dependency invalidation. A `StateNotifier` constructor ran exactly once.**

Any taxi controller whose constructor performs a *side effect* will now perform it repeatedly. Concretely:

```dart
// RideTrackingController today — constructor joins a socket room
RideTrackingController(this.ref, this.rideId) : super(const RideTrackingState()) {
  ref.read(socketServiceProvider).joinRide(rideId);   // ← runs once today
  _subscribe();
  _fetch();
}
```

Migrated naively into `build()`, a single provider invalidation re-joins the room and re-registers listeners — leaking a handler per invalidation, exactly the bug taxi's own socket comments warn about.

Correct shape:

```dart
class RideTrackingController extends Notifier<RideTrackingState> {
  @override
  RideTrackingState build() {
    // Idempotent wiring only, with explicit teardown.
    final channel = ref.watch(socketChannelProvider(BackendIds.taxi));
    final off = channel.addConnectionListener(() => channel.joinRide(rideId));
    channel.joinRide(rideId);
    ref.onDispose(() { off(); channel.leaveRide(rideId); });

    // Kick off async work without awaiting inside build().
    Future.microtask(_fetch);
    return const RideTrackingState();
  }
}
```

Rules for the migration:
- **`build()` must be pure-ish and idempotent.** Wiring is fine; fire-and-forget network calls need `Future.microtask` (food already uses exactly this pattern in `SocketConnectionNotifier`, with a comment explaining why).
- **Every subscription, timer, and socket room needs a matching `ref.onDispose`.** Taxi's `StateNotifier`s mostly rely on `dispose()`; that maps to `ref.onDispose` but it is easy to drop during a rewrite.
- **Use `AsyncNotifier` where the state is "loading / data / error".** Several taxi controllers hand-roll `isLoading` + `error` fields in their state class; food already uses `AsyncNotifier` in 3 files. Converting those is optional but reduces code.

Add **`riverpod_lint`** for this phase. It catches the common errors (`ref.read` in `build`, missing dispose, provider used outside scope) automatically, which matters when six people are touching twelve files.

---

## 8.4 Provider scoping — the memory story

Today both apps put everything in one root `ProviderScope`. That is fine for one product; for four it is the difference between an app that holds ~90 MB and one that climbs past 250 MB in a long session.

```
ProviderScope (root)  ─ app scope, never disposed
│   env · flags · kvStore · tokenStorage · apiClientRegistry
│   socketGateway · pushService · connectivity
│   sessionController · authController · userController
│   activeJobsController        ← must survive module switches
│   themeController · localeController · moduleRegistry
│
├── ProviderScope (food)   installed by /food/* ShellRoute
│     foodCatalogController · cartController · checkoutController
│     restaurantController · store99Controller · favoritesController
│     foodZoneController
│
├── ProviderScope (taxi)   installed by /taxi/* ShellRoute
│     bookingController · destinationSearchController
│     rideTrackingController · fareCalculator · vehicleTypesController
│
├── ProviderScope (parcel)
└── ProviderScope (rental)
```

### What goes where — the decision rule

Ask: **"if the user leaves this module, must this state survive?"**

| State | Scope | Why |
|---|---|---|
| Auth session, user profile | **app** | Everything depends on it |
| Wallet balance | **app** | Shown in the hub and in every checkout |
| Active jobs (order in flight, ride in progress) | **app** | The whole point of the floating card is that it follows you |
| Notification inbox unread count | **app** | Badge on the hub |
| Theme mode, locale | **app** | Global |
| Socket gateway | **app** | Connections outlive module visits |
| Food cart | **module (food)** | …with a caveat, below |
| Restaurant list, filters, scroll position | **module (food)** | Cheap to refetch; expensive to hold |
| Booking funnel state (pickup, drop, chosen vehicle) | **module (taxi)** | …with a caveat, below |
| Ride tracking | **module (taxi)** + app-level active job | The screen state is module; the *fact* of an active ride is app |
| Vehicle types, fare tables | **module (taxi)**, cached to disk | Taxi's own comment notes the full catalogue is ~7 MB — never hold it at app scope |

**The two caveats matter.** A food cart must not be lost because the user checked their wallet, and a half-built ride booking must not be lost because they glanced at the hub. Two options:

- **Persist, don't hold.** The cart already syncs to `/food/user/cart`; the booking funnel can persist to Hive. Module scope disposes the in-memory copy, and re-entering rehydrates. This is the recommended approach — it also survives an app kill, which holding in memory never does.
- **Promote to app scope** with an explicit "clear on completion" rule. Simpler, but it means four modules' funnels all resident forever.

Recommendation: persist. Food's cart already has the endpoint. Taxi's booking funnel needs a small `BookingDraft` DTO in Hive — maybe 60 lines, and it makes "resume your booking" possible, which is a product win.

### `autoDispose` guidance

With module scoping, `autoDispose` finally does something useful. Use it for:
- anything holding a `GoogleMapController` or a large image list
- per-detail-screen controllers (`restaurantDetailController(id)`, `rideDetailController(id)`) — always `.family` + `.autoDispose`
- search controllers with debounce timers

Do **not** use it for module-level funnel controllers, or navigating between two screens of the same funnel will reset it. That is precisely the class of bug to expect in Phase 5, so it is worth writing down.

---

## 8.5 DI organisation

### Today

Food's `src/di/` — 16 files, 349 lines, one per concern:
```
account · address · auth · catalog · chat · favorites · location · network
order · payment · push · restaurant · search · socket · store99 · wallet
```
Small, focused, easy to navigate. Keep the pattern.

Taxi's `core/providers/core_providers.dart` — 51 lines, everything platform-level in one file, using the boot-override pattern:
```dart
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  throw UnimplementedError('must be overridden');
});
```
overridden in `main.dart` with instances created during bootstrap. That is the right technique for anything requiring async init — keep it.

### Merged

```
app/di/
├── boot_overrides.dart      the override list built by bootstrap()
└── app_providers.dart       router · moduleRegistry · rootNavigatorKey · flags

core/<area>/*_providers.dart   colocated with the service they construct
                               core/network/network_providers.dart
                               core/push/push_providers.dart
                               core/realtime/realtime_providers.dart
                               core/storage/storage_providers.dart
                               core/location/location_providers.dart

shared/<feature>/application/<feature>_providers.dart
modules/<module>/application/<module>_providers.dart
```

**Colocate providers with what they build.** Food's separate `di/` folder was reasonable for one product, but in a four-module tree it means `di/` accumulates entries for four modules and stops being navigable. A provider next to its service is easier to keep correct.

### Boot overrides

```dart
// app/di/boot_overrides.dart
List<Override> bootOverrides(BootResult boot) => [
  envProvider.overrideWithValue(boot.env),
  kvStoreProvider.overrideWithValue(boot.kv),
  tokenStorageProvider.overrideWithValue(boot.secure),
  featureFlagsProvider.overrideWithValue(boot.flags),
  // NOTE: boxStoreProvider is NOT here. Hive boxes open lazily per module.
];
```

That last comment is the concrete change from taxi's current behaviour, which opens all five boxes before `runApp`.

---

## 8.6 Keyed providers for multi-backend and per-module services

The transition period needs services parameterised by endpoint. `Provider.family` handles it:

```dart
// core/network/network_providers.dart
final apiClientProvider = Provider.family<ApiClient, String>((ref, endpointId) {
  final endpoint = ref.watch(endpointProvider(endpointId));
  return ApiClient(
    baseUrl: endpoint.baseUrl,
    tokens: ref.watch(tokenStorageProvider),
    supportsRefresh: endpoint.authScheme == AuthScheme.bearerWithRefresh,
    onSessionExpired: () => ref.read(sessionControllerProvider.notifier).expire(),
  );
});

// core/realtime/realtime_providers.dart
final socketChannelProvider = Provider.family<SocketChannel, String>((ref, endpointId) {
  final channel = ref.watch(socketGatewayProvider).channel(endpointId);
  ref.onDispose(channel.release);
  return channel;
});
```

A module's repository then reads its own client:

```dart
final foodOrderRepositoryProvider = Provider((ref) => FoodOrderRepository(
  ref.watch(apiClientProvider(FoodModule.endpointIdConst)),
));
```

After the backend merge, every module's `endpointId` returns `'unified'`, the family resolves to one instance, and **no repository changes.** That is the payoff for the extra indirection.

---

## 8.7 Controller ownership map

Who owns what, after the merge. This is the answer to the brief's "Shared / Food / Taxi / Global Controllers".

### Global (app scope) — 14

| Controller | Origin | Notes |
|---|---|---|
| `sessionController` | **new** (food's `SessionExpiredNotifier` + taxi's `misc/` screens) | Single navigation authority |
| `authController` | food's `AuthViewModel` (197) + taxi's `AuthController` (139) | B1/B2 |
| `userController` | food's account datasource | Identity only |
| `walletController` | food's `WalletViewModel` (127) | B6 |
| `activeJobsController` | food's `ActiveOrderViewModel` (136), generalised | Multi-module |
| `notificationInboxController` | food's (165) + taxi's | B4 |
| `themeController` | food's 2 providers + taxi's 1 | Merged |
| `localeController` | taxi's `LocaleNotifier` | Ported |
| `connectivityController` | **new** (`connectivity_plus`) | Replaces food's poll |
| `featureFlagsController` | **new** | Drives module enablement |
| `addressController` | food's `AddressViewModel` (127) + taxi's saved places | B8 |
| `referralController` | food's | |
| `couponController` | food's `CouponsViewModel` (57) + taxi's promo | B9 |
| `hubController` | taxi's `all_services_screen` providers | Reads `/users/app-modules` |

### Food module scope — 17

`foodHomeController` · `bannersController` · `nearYouController` · `restaurantListController` · `vegFilterController` · `foodZoneController` · `restaurantController` · `restaurantDetailController` (family) · `store99Controller` · `cartController` · `checkoutController` · `favoritesController` · `foodOrdersController` · `orderTrackingController` (family) · `orderConversationsController` · `foodSearchController` · `foodCatalogPrefetchController`

All already `Notifier`-based. Work is renaming (`*ViewModel` → `*Controller`) and moving into module scope.

### Taxi module scope — 8

`bookingController` (PORT) · `destinationSearchController` (PORT) · `rideTrackingController` (PORT) · `fareCalculator` · `vehicleTypesController` · `setPricesController` · `nearbyDriversController` · `emergencyContactsController` (PORT)

### Parcel module scope — 3
`parcelBookingController` (PORT) · `parcelCategoriesController` · `parcelVehiclesController`

### Rental module scope — 3
`rentalVehiclesController` · `rentalBookingController` · `rentalQuoteController`

### Deleted controllers — 9

`ride_history_controller` · `saved_places_provider` · `recent_searches_provider` · taxi's `theme_provider` · taxi's `auth_controller` (merged) · taxi's `wallet_providers` · taxi's `notifications_providers` · taxi's `promo_providers` · food's 1-line `referral_viewmodel`

---

## 8.8 Cross-module communication without coupling

A module must never `ref.read` another module's provider. Three sanctioned channels:

**1. Shared app-scope state.** Food's checkout reads `walletControllerProvider`. That is not cross-module coupling — the wallet is shared.

**2. Event bus for fire-and-forget facts.** Rare, but genuinely needed:

```dart
// core/events/app_events.dart
sealed class AppEvent {
  const factory AppEvent.jobStarted(ModuleId m, String id)   = JobStarted;
  const factory AppEvent.jobCompleted(ModuleId m, String id) = JobCompleted;
  const factory AppEvent.paymentSucceeded(PaymentIntent i)   = PaymentSucceeded;
  const factory AppEvent.loggedOut()                         = LoggedOut;
}
final appEventsProvider = Provider<Stream<AppEvent>>(…);
```

`activeJobsController` listens; `walletController` refreshes on `paymentSucceeded`; every module's cache clears on `loggedOut`. No module knows another exists.

**3. The registry**, for anything needing per-module contributions — which is most things (§2.4).

**Anti-pattern to reject in review:** a `sharedFoodCartProvider` at app scope so taxi can "check if there's a food order". If two modules need a fact, it belongs in `shared/`, properly modelled — not smuggled through a provider name.

---

## 8.9 `ConsumerStatefulWidget` audit

70 files across both apps use `ConsumerStatefulWidget` (34 food, 36 taxi) vs 36 using `ConsumerWidget`. That ratio is high, and it usually means local state that should be in a provider — but it is also often legitimate (`AnimationController`, `TextEditingController`, `ScrollController`, `GoogleMapController`).

Not a merge blocker, but two rules going forward:

- **`ConsumerStatefulWidget` is for widget-lifecycle objects only** — animation, text, scroll, map controllers. Anything else goes in a provider.
- **`ref.listen` in `build`, not `ref.watch` in `initState`.** Both apps get this right today (food's `food_user_application.dart` uses `ref.listen` for the auth→push wiring correctly), but it is the most common Riverpod mistake and worth a lint.

---

## 8.10 Migration order

```
1. Rename food's *ViewModel → *Controller.              17 files, mechanical, no behaviour change
2. Resolve the 6 global-name collisions.                 Pick winners; delete losers
3. Convert apiClientProvider → Provider.family.          Food's repos gain one argument
4. Introduce module ProviderScopes (food only).          Move food's 17 controllers to module scope
                                                         ← first real memory win, measurable
5. TAXI REPO: migrate 6 genuine StateNotifiers → Notifier.
                                                         With riverpod_lint. Test the ride flow hard
6. Import taxi's controllers into modules/taxi.
7. Split parcel + rental controllers out.
8. Collapse shared controllers.                          ← gated on B1/B6/B8/B9
9. Add appEventsProvider + activeJobsController.         Enables the multi-module floating card
```

Steps 1–4 are food-only and can start immediately. Step 5 belongs in the taxi repo, before the merge (see [Ch. 5 §5.8](04-dependency-merge.md)) — migrating twelve controllers inside a tree that does not compile is the single most avoidable way to lose a week.
