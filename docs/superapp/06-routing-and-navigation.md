# Chapter 7 — Routing and Navigation

Route collisions, the namespaced route tree, shell design, deep links, and how the module registry owns route assembly.

---

## 7.1 Current state

### Food — `src/presentation/navigation/app_router.dart` (364 lines)

A `Provider<GoRouter>` (good — it can read other providers), `initialLocation: '/'`, and a `StatefulShellRoute.indexedStack` with four branches. 32 routes total.

```
/                          splash
/login  ?from=             login  (guest-mode aware — returns you afterwards)
/otp                       otp    (extra: phone, devOtp, from)
/restaurant-detail         + /restaurant-detail/:id
/food-detail   /food       two paths, same screen (share-link tolerance)
/search        ?q=
/orders
/notifications
/orders/details/:id   /orders/track/:id   /orders/delivered/:id   /orders/success/:id
/chat                      extra: ChatArgs
/home-filter               extra: HomeFilterArgs (required cast — will throw if absent)
/referral      /refer-earn/ticket
/favorites     /add-address     /all-offers     /wallet
/webview       /about    /help-support   /privacy-policy   /terms-conditions
/edit-profile
/buy-again                 wraps CartScreen in a nested ProviderScope with overrides
└─ StatefulShellRoute.indexedStack
     ├─ /home       (shellHome)
     ├─ /cart       (shellCart)
     ├─ /store-99   (shellStore99)
     └─ /profile    (shellProfile)
```

What food does right: a router **provider**; a real stateful shell that preserves per-branch navigation state; `parentNavigatorKey: rootNavigatorKey` on routes that must cover the shell; loader screens for id-only deep links (`RestaurantDetailLoaderScreen`, `FoodDetailLoaderScreen`) instead of unconditionally casting `state.extra`; a `?from=` parameter so guest→login→return works.

What it does wrong: `RouteNames` is a flat bag of 35 constants with no namespacing; `/home-filter` does `state.extra as HomeFilterArgs` unguarded; `/buy-again` creates a nested `ProviderScope` inside a route builder, which is clever but fragile.

### Taxi — `app/router.dart` (217 lines)

A **global `final appRouter`** (cannot read providers), `initialLocation: '/'`, **no shell at all**. 60 flat routes.

```
/  /onboarding
/auth/{phone,otp,signup,location-permission,notification-permission,account-created}
/home  /home/{all-services,search,map-picker,saved-places,ride-types,promo,
              confirm,finding-driver,no-driver}
/search                        → redirect('/home/search')
/ride/tracking/:rideId   /ride/:rideId/chat   /ride/:rideId/rating
/rides   /ride/history   /rides/:rideId   /ride/detail/:rideId
/wallet
/notifications  /notifications/settings
/profile  /profile/{edit,emergency-contacts,language,theme,delete-account}
/support  /support/{safety-center,new-ticket,tickets/:ticketCode,sos}
/settings  /settings/{privacy,terms,security,about}
/rental  /rental/history  /rental/:vehicleId/book
/delivery/{new,vehicle,vehicle/:categoryId,address,finding/:rideId,history}
/subscription  /rewards
/system/{force-update,maintenance,no-internet,server-error,gps-disabled,
         location-permission-denied,session-expired,force-logout}
errorBuilder → "Page not found"
```

What taxi does right: **path segments are already hierarchical** (`/auth/*`, `/support/*`, `/settings/*`, `/system/*`) — much closer to the target shape than food's flat names; an `errorBuilder` (food has none); duplicate aliases for the same screen (`/rides` and `/ride/history`; `/rides/:id` and `/ride/detail/:id`) which is defensive but suggests the paths were never settled.

What it does wrong: a global router that cannot read auth state, so redirects have to be done imperatively from screens; no shell, so `AppBottomNavigationBar(currentIndex: 2)` is hand-passed on every screen and every tab switch rebuilds the destination from zero; `state.extra as String? ?? ''` and `state.extra as RentalVehicleModel` — the latter throws on a cold deep link.

---

## 7.2 Collision table

### Exact path collisions — 6

| Path | Food | Taxi | Resolution |
|---|---|---|---|
| `/` | `SplashScreen` (247) | `SplashScreen` (61) | One shared splash → resolves to `/hub` |
| `/home` | food home, inside shell branch 0 | taxi ride-booking home | `/food` and `/taxi` |
| `/search` | food content search | redirect to `/home/search` (destination picker) | `/search` (shared content search) and `/taxi/destination` |
| `/wallet` | `WalletScreen` (926) | `WalletScreen` (128) | `/wallet` — one shared screen |
| `/notifications` | inbox (286) | inbox (94) | `/notifications` — one shared screen |
| `/profile` | shell branch 3, 1,974 lines | 280 lines | `/profile` — one shared screen |

### Semantic collisions — same destination, different path — 11

| Concept | Food path | Taxi path | Merged |
|---|---|---|---|
| Phone entry | `/login` | `/auth/phone` | `/auth/phone` |
| OTP | `/otp` | `/auth/otp` | `/auth/otp` |
| Profile setup | (in-flow) | `/auth/signup` | `/auth/profile-setup` |
| Edit profile | `/edit-profile` | `/profile/edit` | `/profile/edit` |
| About | `/about` | `/settings/about` | `/settings/about` |
| Privacy | `/privacy-policy` | `/settings/privacy` | `/settings/legal/privacy` |
| Terms | `/terms-conditions` | `/settings/terms` | `/settings/legal/terms` |
| Job history | `/orders` | `/rides`, `/ride/history` | `/activity` (+ `?tab=food\|ride\|parcel`) |
| Chat | `/chat` | `/ride/:rideId/chat` | `/support/chat` with a `ChatContext` |
| Saved addresses | `/add-address` | `/home/saved-places` | `/addresses` and `/addresses/edit` |
| Referral / rewards | `/referral` | `/rewards` | `/referral` |

**17 collisions in total.** Every one of them would be a silent bug in a naive merge: whichever `GoRoute` is registered first wins, and `go_router` will not warn you.

### Path-shape collision worth calling out

Food's `/orders/track/:id` and taxi's `/ride/tracking/:rideId` are the *same concept* — "watch a job in progress" — expressed two ways. In the merged app they become `/food/orders/:id/track` and `/taxi/rides/:id/track`, and both are reachable from one place: `shared/activity`.

---

## 7.3 Target route tree

Three tiers, matching the architecture: **root** (session), **shared**, **module**.

```
/                                        splash → redirects on SessionState
/onboarding                              first-run carousel
│
├── /auth
│     /auth/phone                        phone entry
│     /auth/otp                          otp            (extra: OtpArgs)
│     /auth/profile-setup                new-account details
│     /auth/permissions/location
│     /auth/permissions/notifications
│     /auth/welcome                      account created
│
├── /hub                                 ★ SUPER-APP HOME — module launcher
│
├── ── SHARED ──────────────────────────────────────────────────────
│     /activity            ?tab=all|food|ride|parcel|rental
│     /wallet              /wallet/topup   /wallet/transactions
│     /profile             /profile/edit   /profile/delete
│     /addresses           /addresses/new   /addresses/:id/edit
│                          /addresses/pick   (modal picker + map)
│     /notifications       /notifications/settings
│     /support             /support/chat     (extra: ChatContext)
│                          /support/tickets  /support/tickets/:code
│                          /support/tickets/new
│                          /support/safety   /support/sos
│     /settings            /settings/theme   /settings/language
│                          /settings/security /settings/about
│                          /settings/legal/:key       ← CMS-driven
│     /offers              /offers/coupons
│     /referral            /referral/ticket
│     /subscription
│     /search              ?q=            (shared content search)
│     /webview             ?url=&title=
│
├── ── MODULE: FOOD ────────────────────────────────────────────────
│     ShellRoute → ProviderScope(FoodModule overrides) + ModuleTheme(food)
│       StatefulShellRoute.indexedStack
│         ├─ /food                              home
│         ├─ /food/cart
│         ├─ /food/store99
│         └─ /food/orders                       food-scoped order list
│     /food/restaurants/:id                     (+ loader for id-only links)
│     /food/dishes/:id            ?restaurantId=
│     /food/filter                              (extra: HomeFilterArgs, guarded)
│     /food/favorites
│     /food/orders/:id                          details
│     /food/orders/:id/track
│     /food/orders/:id/success
│     /food/orders/:id/delivered
│     /food/reorder                             (extra: List<CartItem>)
│
├── ── MODULE: TAXI ────────────────────────────────────────────────
│     ShellRoute → ProviderScope(TaxiModule overrides) + ModuleTheme(taxi)
│     /taxi                                     booking home (map)
│     /taxi/destination                         place autocomplete
│     /taxi/pick-on-map        ?type=pickup|drop
│     /taxi/vehicles                            ride types + fares
│     /taxi/confirm
│     /taxi/searching
│     /taxi/no-driver
│     /taxi/rides/:id/track
│     /taxi/rides/:id                           detail
│     /taxi/rides/:id/rate
│     /taxi/emergency-contacts
│
├── ── MODULE: PARCEL ──────────────────────────────────────────────
│     /parcel                                   new parcel
│     /parcel/vehicles       /parcel/vehicles/:categoryId
│     /parcel/addresses
│     /parcel/searching/:jobId
│     /parcel/jobs/:id/track
│
├── ── MODULE: RENTAL ──────────────────────────────────────────────
│     /rental
│     /rental/vehicles/:id/book                 (+ loader, not a raw cast)
│     /rental/bookings/:id
│
└── ── SYSTEM ──────────────────────────────────────────────────────
      /system/update-required   /system/maintenance   /system/offline
      /system/server-error      /system/gps-disabled  /system/location-denied
      /system/session-expired   /system/logged-out
      errorBuilder → NotFoundScreen  (with a "go to hub" action)
```

Design rules encoded above:

1. **Every module route starts with the module id.** No exceptions. This alone eliminates all 6 exact collisions and makes the ownership of any route obvious from the URL.
2. **Shared routes are un-prefixed.** `/wallet` means *the* wallet. If a path has no module prefix, it is shared — that is the reading rule.
3. **Resource-shaped module paths** (`/food/orders/:id/track`, not `/orders/track/:id`) so the noun comes before the verb and sub-resources nest naturally.
4. **`/hub` is a real route,** not "whatever the first tab is". Back-from-module goes to `/hub`.
5. **Loader screens for every id-only route.** Food already does this for restaurants and dishes; taxi's `/rental/:vehicleId/book` does `state.extra as RentalVehicleModel` and will throw on a cold deep link. Every `:id` route must work with the id alone.

---

## 7.4 Route assembly through the registry

The router is a provider that asks the registry for module routes. Nobody edits the router to add a module.

```dart
// app/di/app_providers.dart
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final registry = ref.watch(moduleRegistryProvider);
  final flags    = ref.watch(featureFlagsProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,

    // One place decides what the user may see. See §7.7.
    redirect: (context, state) => ref.read(routeGuardProvider).resolve(state),

    // Rebuilds the redirect when session state changes.
    refreshListenable: ref.watch(sessionListenableProvider),

    routes: [
      ...sessionRoutes(rootNavigatorKey),      // / · /onboarding · /auth/* · /system/*
      hubRoute(rootNavigatorKey),              // /hub
      ...sharedRoutes(rootNavigatorKey),       // /wallet · /activity · /profile · …

      // every enabled module contributes its own subtree
      for (final m in registry.enabled(flags))
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell-${m.id.name}'),
          builder: (context, state, child) => ProviderScope(
            overrides: m.providerOverrides(),
            child: ModuleTheme(accent: m.accent, child: child),
          ),
          routes: m.routes(rootNavigatorKey),
        ),
    ],

    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
  );
});
```

Three properties follow:

- **`registry.enabled(flags)`** means a server-disabled module's routes do not exist. A deep link into a disabled module hits `errorBuilder` rather than a half-initialised screen — which is the correct behaviour for a staged rollout.
- **The `ShellRoute` wrapper is where module DI and module theming live.** Entering `/taxi/*` installs taxi's provider overrides and accent; leaving disposes them.
- **`refreshListenable`** is what makes `redirect` re-run on login/logout. Taxi's global router cannot do this at all today, which is why its auth navigation is imperative.

### Module route file shape

```dart
// modules/food/food_routes.dart
List<RouteBase> foodRoutes(GlobalKey<NavigatorState> rootKey) => [
  StatefulShellRoute.indexedStack(
    builder: (c, s, shell) => FoodShell(navigationShell: shell),
    branches: [
      StatefulShellBranch(navigatorKey: _homeKey,   routes: [GoRoute(path: '/food',          builder: …)]),
      StatefulShellBranch(navigatorKey: _cartKey,   routes: [GoRoute(path: '/food/cart',     builder: …)]),
      StatefulShellBranch(navigatorKey: _store99Key,routes: [GoRoute(path: '/food/store99',  builder: …)]),
      StatefulShellBranch(navigatorKey: _ordersKey, routes: [GoRoute(path: '/food/orders',   builder: …)]),
    ],
  ),
  GoRoute(
    path: '/food/restaurants/:id',
    parentNavigatorKey: rootKey,                 // covers the shell
    builder: (c, s) {
      final extra = s.extra;
      return extra is RestaurantModel
          ? RestaurantScreen(restaurant: extra)   // warm push — no refetch
          : RestaurantLoaderScreen(id: s.pathParameters['id']!);  // cold link
    },
  ),
  // …
];
```

That `extra is X ? … : Loader(id)` pattern is food's existing approach and it is the right one. **Apply it to every module route that takes a model in `extra`** — taxi currently has three unguarded casts (`/auth/otp`, `/auth/signup`, `/rental/:vehicleId/book`) and food has one (`/home-filter`).

---

## 7.5 Shell design

Three levels of chrome, which is the part a naive merge gets wrong by trying to have one bottom nav for everything.

```
┌─ app_shell.dart  (wraps EVERY route, never rebuilds on navigation) ────┐
│   • OfflineBanner                                                      │
│   • SessionWatcher      → routes on SessionState changes                │
│   • FloatingActiveJobCard(s)  ← food order AND/OR live ride            │
│   • global snackbar/toast host                                         │
│                                                                        │
│  ┌─ /hub ────────────────┐  ┌─ /food/* shell ──────┐  ┌─ /taxi/* ────┐ │
│  │ module tiles          │  │ StatefulShellRoute    │  │ ShellRoute   │ │
│  │ active jobs           │  │ 4 branches, own       │  │ no bottom    │ │
│  │ shortcuts             │  │ bottom nav            │  │ nav — the    │ │
│  │ NO bottom nav         │  │ (food-accented)       │  │ map is the   │ │
│  └───────────────────────┘  └───────────────────────┘  │ UI           │ │
│                                                        └──────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

**Per-module navigation, not one global bottom nav.** Reasons:

- Food genuinely needs 4 tabs with preserved state (browse → cart → back to browse must not lose scroll position). Food already has this via `StatefulShellRoute.indexedStack` + 4 `navigatorKey`s.
- Taxi's booking flow is a **linear funnel over a map** (home → destination → vehicles → confirm → searching → tracking). A bottom nav mid-funnel is a way to lose a half-built booking. Taxi's current `AppBottomNavigationBar` on booking screens is a design bug that the merge should fix, not preserve.
- Parcel is likewise a funnel.

So: the **hub** is the top-level switcher, each module owns its internal navigation, and shared destinations (`/wallet`, `/activity`, `/profile`) are reachable from the hub and from each module's own entry points.

### Active-job cards are app-level, not module-level

Food already has `FloatingActiveOrderCard` (248 lines) driven by `activeOrderViewModelProvider`, rendered by `MainAppShell`. Generalise:

```dart
// shared/activity/application/active_jobs_controller.dart — APP SCOPE
class ActiveJobsController extends Notifier<List<ActiveJob>> { … }

class ActiveJob {
  final ModuleId module;
  final String id;
  final String status, title, subtitle;
  final String trackRoute;      // '/food/orders/x/track' | '/taxi/rides/y/track'
  final double? progress;
}
```

A user can have a food order *and* a ride in flight simultaneously. That is a genuinely new state neither app has ever had, and it must be designed for rather than discovered in production: stack up to two cards, collapse to a pill beyond that.

### Back-button semantics

Food's `MainAppShell` has a `PopScope` that goes to branch 0 first, then shows an exit confirmation. Extend to three levels:

```
inside a module, not at its entry route   → pop within the module
at a module's entry route                 → go to /hub
at /hub                                   → exit confirmation dialog
```

The existing `exit_confirmation_dialog.dart` (135 lines) moves to the design system and is used only at `/hub`.

---

## 7.6 Deep links

### Today

Food's manifest declares:

```xml
<intent-filter android:autoVerify="true">
  <data android:scheme="https" android:host="suvio.appzeto.com"
        android:pathPrefix="/food-detail" />
  <data android:scheme="https" android:host="suvio.appzeto.com"
        android:pathPrefix="/restaurant-detail" />
  <!-- + http variants -->
</intent-filter>
<intent-filter>
  <data android:scheme="suvio" />
</intent-filter>
```

with a comment recording that the host used to be `suvio.app` — a domain they do not control, so `autoVerify` could never succeed. Good comment; exactly the kind of trap to avoid repeating.

Taxi declares **no deep links at all**.

Food also has `domain/service/deep_link_service.dart` (115 lines), which only knows food paths.

### Merged design

| Concern | Decision |
|---|---|
| Custom scheme | **One** scheme for the super app (e.g. `suvio://`). Two schemes means two apps' worth of OS registration for one binary |
| Web host | One verified host. `assetlinks.json` must be servable from it — this is the trap food already hit |
| Path prefixes | Add one `pathPrefix` per module, matching the route tree: `/food`, `/taxi`, `/parcel`, `/rental`, plus shared `/activity`, `/wallet`, `/referral` |
| Resolution | `core/utils/deep_link_parser.dart` normalises the incoming URI, then the **module registry** claims it. `DeepLinkService`'s food-only knowledge moves into `FoodModule` |
| Legacy links | Old `suvio.appzeto.com/restaurant-detail/:id` links exist in the wild (shared by users). Add permanent redirects: `/restaurant-detail/:id` → `/food/restaurants/:id`, `/food-detail` → `/food/dishes/:id` |
| Auth-gated targets | A deep link to `/wallet` while logged out must land on `/auth/phone` and **return** afterwards. Food's `?from=` mechanism generalises — carry the intended location through the auth flow |

Legacy redirects, concretely:

```dart
GoRoute(path: '/restaurant-detail/:id',
        redirect: (c, s) => '/food/restaurants/${s.pathParameters['id']}'),
GoRoute(path: '/food-detail',
        redirect: (c, s) => '/food/dishes/${s.uri.queryParameters['id'] ?? ''}'),
GoRoute(path: '/orders/track/:id',
        redirect: (c, s) => '/food/orders/${s.pathParameters['id']}/track'),
GoRoute(path: '/rides',        redirect: (c, s) => '/activity?tab=ride'),
GoRoute(path: '/ride/history', redirect: (c, s) => '/activity?tab=ride'),
```

Keep these for at least two release cycles — they cost five lines each and they are the difference between an old shared link working and showing "Page not found". **Also note push payloads in flight:** food's backend currently sends `link: '/food/user/orders/<id>'` in FCM data. Until the backend updates, the push router must tolerate the old shape.

---

## 7.7 Route guards and the redirect

One `redirect` reading one `SessionState` — replacing today's arrangement where the 401 interceptor, the splash screen, an auth listener in `food_user_application.dart`, and taxi's `NoDriverWatcher` all push routes independently.

```dart
// app/routing/route_guard.dart
String? resolve(GoRouterState state) {
  final session = ref.read(sessionControllerProvider);
  final loc = state.matchedLocation;

  // 1. Hard blocks first — nothing else matters.
  switch (session) {
    case UpdateRequired(): return loc == '/system/update-required' ? null : '/system/update-required';
    case Maintenance():    return loc == '/system/maintenance'     ? null : '/system/maintenance';
    case Booting():        return loc == '/'                       ? null : '/';
    case ForcedOut():      return loc == '/system/logged-out'      ? null : '/system/logged-out';
    default: break;
  }

  // 2. Onboarding, once.
  if (!ref.read(kvStoreProvider).onboardingSeen && !loc.startsWith('/onboarding')) {
    return '/onboarding';
  }

  // 3. Auth-gated destinations.
  if (_requiresAuth(loc) && session is! Authenticated) {
    return '/auth/phone?from=${Uri.encodeComponent(state.uri.toString())}';
  }

  // 4. Don't strand an authenticated user on the auth flow.
  if (loc.startsWith('/auth') && session is Authenticated) {
    return state.uri.queryParameters['from'] ?? '/hub';
  }

  // 5. Disabled module → hub.
  final moduleId = ModuleId.fromPath(loc);
  if (moduleId != null && !ref.read(moduleRegistryProvider)
        .isEnabled(moduleId, ref.read(featureFlagsProvider))) {
    return '/hub';
  }

  return null;
}
```

### Guest mode is a design decision, not an accident

The two apps differ and the merged app must pick deliberately:

| | Food today | Taxi today |
|---|---|---|
| Browse without login | **yes** — restaurants, dishes, search all work; `/login?from=` returns you | **no** — everything is behind auth |

Recommended `_requiresAuth` set:

```
requires auth: /wallet  /activity  /profile  /addresses  /referral
               /notifications  /support/tickets  /subscription
               /food/cart (checkout step)  /taxi/confirm  /parcel/addresses

guest allowed: /hub  /food  /food/restaurants/*  /food/dishes/*  /food/store99
               /search  /offers  /settings/*  /taxi (map + fare estimate)
               /taxi/destination  /taxi/vehicles
```

Letting a guest see a **fare estimate** before signing up is a meaningful conversion improvement over taxi's current behaviour, and the architecture supports it — the estimate endpoint (`/users/set-prices`, `fare_calculator.dart`) needs no auth. Confirm with product; flag it as an opportunity the merge unlocks.

---

## 7.8 Navigation between modules

Cross-module navigation happens by **path string**, never by importing another module's screen — this is the rule that keeps modules independent.

```dart
// modules/food — WRONG. Creates a compile-time dependency on taxi.
context.push('/taxi', extra: TaxiBookingArgs(…));
import '../../taxi/presentation/booking/taxi_home_screen.dart';   // ✗ lint error

// RIGHT. A string, plus a typed args map the target parses.
context.push(ModuleRoutes.taxi.entry, extra: const CrossModuleArgs.prefill(…));
```

`ModuleRoutes` is a tiny constants class in `modules/` (not inside any module) holding each module's entry route. It is the only cross-module coupling, and it is one line per module.

Two real cross-module flows to expect:

- **Hub → module** with context ("Order again from Pizza Hut" → `/food/restaurants/x`).
- **Activity → module** ("track this ride" → `/taxi/rides/y/track`). `ActiveJob.trackRoute` already carries the string, so the activity screen never learns what a ride is.

---

## 7.9 Named routes vs. paths

Food uses raw path strings via `RouteNames` constants. Taxi uses raw strings inline. For a super app, use **`name:` on every route** and navigate with `goNamed`/`pushNamed`:

```dart
GoRoute(
  name: FoodRouteNames.restaurantDetail,       // 'food.restaurant.detail'
  path: '/food/restaurants/:id',
  builder: …,
);

context.pushNamed(FoodRouteNames.restaurantDetail, pathParameters: {'id': id});
```

Why it matters more here than in a single-product app: with 4 modules and ~90 routes, a path typo in a string literal is a runtime "Page not found" that no compiler catches. Named routes give you one place to change a path, and `pathParameters` is checked at the call site. Namespace names as `<module>.<area>.<screen>` so they cannot collide either.

---

## 7.10 Route inventory — before and after

| | Food | Taxi | Merged |
|---|---|---|---|
| Routes | 32 | 60 | ~90 |
| Shells | 1 (4 branches) | 0 | 1 global + 1 per module |
| Exact collisions | — | — | **0** (was 6) |
| Semantic duplicates | — | — | **0** (was 11) |
| Legacy redirects | — | — | 5+ |
| Unguarded `state.extra` casts | 1 | 3 | **0** — loader screen for every id route |
| Router can read providers | yes | **no** | yes |
| Single redirect authority | no | no | **yes** |
| `errorBuilder` | **no** | yes | yes |

---

## 7.11 Migration order for routing

Routing is a good first structural task because it forces the module boundaries to be real before any code moves.

1. **Define the whole route tree as constants** (`app/routes.dart` + `modules/*/​*_route_names.dart`). No behaviour, just names. Reviewable in isolation.
2. **Stand up `routerProvider` + registry with food only.** Food's 32 routes get namespaced to `/food/*`; legacy redirects added. The app still works exactly as before; every food path changes.
3. **Add the `redirect` guard + `SessionController`.** Delete the imperative navigation from `food_user_application.dart` and the splash screen.
4. **Add `/hub`** (initially a two-tile screen: Food, and a disabled Taxi placeholder).
5. **Import taxi's routes as `/taxi/*`,** with `TaxiModule.routes()` — this is where the go_router 14→17 migration lands, on a route set that is being rewritten anyway.
6. **Split `/parcel/*` and `/rental/*`** out of the taxi route list.
7. **Move shared destinations** (`/wallet`, `/activity`, `/profile`, `/notifications`, `/support`, `/settings`) out of both modules — this is the step gated on the backend, and it is deliberately last.

Steps 1–4 can be done before the merged backend exists. That is roughly half the routing work, available immediately.
