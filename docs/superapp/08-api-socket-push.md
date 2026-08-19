# Chapters 9, 10, 11 — API Layer, Socket.IO, Firebase Notifications

The three systems that touch the backend directly, and therefore the three most affected by the backend merge.

---

# Chapter 9 — API Layer

## 9.1 Current API surfaces

### Food — `src/core/config/api_config.dart`

Host `https://suvio.appzeto.com`, base `{host}/api/v1`, **every path under `/food/*`**. Overridable via `--dart-define=API_HOST` / `API_BASE_URL`.

```
Auth        /food/auth/user/request-otp · /food/auth/user/verify-otp
            /food/auth/refresh-token · /food/auth/logout · /food/auth/me
User        /food/user/profile · /profile/profile-image · /addresses · /cart
            /wallet · /cashback · /refunds · /referrals/stats · /referrals/details
            /favorites · /favorites/restaurants · /favorites/foods
Chat        /food/chat/conversations · /messages · /conversations/:id/read
Discovery   /food/restaurant/restaurants (+ /:id, /:id/menu, /:id/addons,
            /:id/outlet-timings) · /public/foods · /categories/public
            /offers · /food/search/unified
Home        /food/hero-banners/public · /hero-banners/home-promotion/public
            /top-banners/public · /explore-icons/public · /landing/settings/public
Zones       /food/zones/detect
Orders      /food/orders (+ /:id) · /orders/calculate · /orders/verify-payment
Notif       /food/notifications/inbox · /fcm-tokens/mobile/save
            /fcm-tokens/remove · /fcm-tokens/test        ← NOT under /food
CMS         /food/admin/business-settings/public · /feature-settings/public
            /fee-settings/public · /food/pages/:key
```

Note `/fcm-tokens/*` sits **outside** the `/food` namespace — food's backend already has a shared area. Useful precedent.

### Taxi — `core/constants/api_constants.dart`

Base `https://taxi.appzeto.com/api/v1` (hardcoded `const`, no dart-define). Confirmed mount: `src/app.js` → `app.use('/api', taxiRouter); app.use('/api/v1', taxiRouter);`

```
Auth        /users/auth/send-otp · /verify-otp · /users/otp-login · /register
            /signup · /login · /users/fcm-token
Profile     /users/me · /users/profile-image · /users/me/delete-request
Bootstrap   /users/bootstrap · /app-modules · /settings · /intercity-packages
            /goods-types · /vehicle-types · /vehicle-map-icons · /banners
            /set-prices · /zones · /service-locations · /service-stores
            /rental-vehicles
Notif       /users/notifications
Wallet      /users/wallet · /topup · /transfer · /transfer/driver
            /razorpay/order · /razorpay/verify · /phonepe/order · /phonepe/status
Promo       /promos/validate · /promos/available
Subs        /users/subscriptions/plans · /me · /purchase
Rides       /rides · /rides/active/me · /available-drivers · /app-settings/tip
Rentals     /users/rental-quote-requests · /rental-bookings (+ /active)
            /rental-advance/{wallet,razorpay/*,phonepe/*}
Deliveries  /deliveries
Bus         /users/buses (+ /routes, /search, /:id/seats) · /bus-bookings (+ /order, /verify)
Pooling     /users/pooling (+ /search, /routes/:id) · /pooling/bookings (+ /order, /verify)
SOS         /users/sos
Support     /support/titles · /support/tickets · /support/tickets/my
Common      /common/upload/image · /payment-gateway
            /common/referrals/translation · /common/referrals/settings
```

## 9.2 The good news: namespaces do not collide

| Prefix | Owner |
|---|---|
| `/food/*` | food |
| `/users/*` · `/rides/*` · `/deliveries/*` · `/promos/*` · `/support/*` · `/common/*` | taxi |
| `/fcm-tokens/*` | food (shared area) |

**Zero path collisions.** A merged Express app can mount both routers under `/api/v1` with no rewriting:

```js
app.use('/api/v1', foodRouter);   // /food/*, /fcm-tokens/*
app.use('/api/v1', taxiRouter);   // /users/*, /rides/*, /deliveries/*, …
```

That is the single most favourable fact in this whole merge, and it means the API-layer work is about **identity and envelope consistency**, not about URLs.

## 9.3 What does collide: identity

| | Food | Taxi |
|---|---|---|
| OTP request | `POST /food/auth/user/request-otp` → returns a dev OTP | `POST /users/auth/send-otp` → returns `{exists, session:{debugOtp}}` |
| Verify | `POST /food/auth/user/verify-otp` → **`{accessToken, refreshToken}`** + user | `POST /users/auth/verify-otp` → **`{exists, token, user}`** |
| New user branch | `verify-otp` accepts `name`, `referralCode`, `fcmToken` — creates in place | `exists:false` → separate `POST /users/signup` |
| Refresh | `POST /food/auth/refresh-token`, **single-flight with replay** | **none** |
| Session probe | `GET /food/auth/me` | `GET /users/me` |
| Logout | `POST /food/auth/logout` (invalidates the refresh token) | client-side only |
| Token storage | secure, access + refresh, memory-cached | secure, single token |

Three distinct problems:

1. **Two tokens.** A user logged into the merged app has one session. Either one JWT is accepted by both route trees, or the client holds two and the "one user" story is a fiction.
2. **No refresh on the taxi side.** Food's `ApiClient` has a well-built single-flight refresh-and-replay. Against a `bearerOnly` endpoint that path must be disabled, or every 401 triggers a pointless refresh attempt against an endpoint that does not exist.
3. **Different new-user flows.** Food creates the account inside `verify-otp`; taxi returns `exists:false` and requires a second `signup` call. The merged `shared/auth` needs one flow. Taxi's two-step is arguably better UX (name/email collection on its own screen), and food's `profile_setup_screen` already exists — so the recommendation is taxi's shape with food's screens.

### Transitional design (before the backend merge)

```dart
class BackendEndpoint {
  final String id, baseUrl, socketUrl;
  final AuthScheme authScheme;      // bearerWithRefresh | bearerOnly
  final String tokenKey;            // which secure-storage slot
}

const endpoints = {
  'food': BackendEndpoint(id: 'food', baseUrl: 'https://suvio.appzeto.com/api/v1',
      socketUrl: 'https://suvio.appzeto.com',
      authScheme: AuthScheme.bearerWithRefresh, tokenKey: 'auth_food'),
  'taxi': BackendEndpoint(id: 'taxi', baseUrl: 'https://taxi.appzeto.com/api/v1',
      socketUrl: 'https://taxi.appzeto.com',
      authScheme: AuthScheme.bearerOnly,       tokenKey: 'auth_taxi'),
};
```

Login then authenticates against both, keyed by the same phone number, and `SessionController` treats the user as authenticated only when both succeed. It is not elegant, but it is honest — and it is entirely contained in `shared/auth` + `core/config`, so the merged backend collapses it to one entry with no other file changing.

**Do not paper over this with a single token that only works on one host.** The failure mode is a user who can order food but silently gets 401s on every ride call, which will look like a network bug and take days to diagnose.

## 9.4 Merged `ApiClient`

Food's 354-line client, with four changes:

```dart
class ApiClient {
  ApiClient({
    required String baseUrl,               // ← was ApiConfig.baseUrl
    required TokenStorage tokens,
    required String tokenKey,              // ← which token slot
    required bool supportsRefresh,         // ← bearerOnly opts out
    required CacheStore cache,             // ← was SharedPreferences inline
    this.onSessionExpired,
    Dio? dio,
  });
}
```

Everything else survives verbatim, and it is worth listing what that gives every module for free:

| Capability | Where it comes from |
|---|---|
| `{success, message, data}` unwrap, so models parse `data` directly | `_unwrap` |
| Typed `Failure`s (`ValidationFailure`, `AuthFailure`, `NotFoundFailure`, `RateLimitFailure`, `TimeoutFailure`, `NetworkFailure`, `ServerFailure`) | `_failureFor`, `_mapDioException` |
| express-validator field errors extracted from `errors: [{path, msg}]` | `_fieldErrors` |
| Reads **both** `message` and `error` keys — the API is inconsistent about which carries the human-readable reason | `_messageOf` |
| Single-flight 401 refresh with request replay | `_refreshOnce` |
| `validateStatus: s < 500` so the envelope's message survives non-2xx | constructor |
| Null query params dropped, so no `?city=null` | `_clean` |
| Opt-in disk-backed GET cache with synchronous `peek()` for instant paint, and offline fallback on error | `_CacheInterceptor` |

Taxi's 10 repositories (~642 lines) must be rewritten against this. That is the largest mechanical task in the merge, and it is also where taxi gains the most: today `ride_repository.dart` does `Map<String,dynamic>.from(data['user'] ?? {})` by hand and has no typed errors at all.

### Repository pattern

Both apps drift. Food declares 6 abstract `domain/repository` contracts for 10 datasources; taxi has repositories that are really datasources (raw calls, no domain shaping). Pick one shape and apply it everywhere:

```
modules/<m>/api/<m>_endpoints.dart          path constants only
modules/<m>/api/datasources/*_datasource.dart   ApiClient in, DTO out. No business logic
modules/<m>/data/models/*.dart              DTOs with fromJson (+ toJson where needed)
modules/<m>/data/repositories/*.dart        orchestration: cache policy, merges,
                                            pagination, mapping Failure → UI-ready result
modules/<m>/application/*_controller.dart   Notifier. Never touches a datasource directly
```

**Drop the abstract `domain/repository` interfaces.** Food has 132 lines of them across 6 files, and they exist only to be implemented once. They are not earning their keep, and they are not what makes the code testable — Riverpod overrides do that. Delete the interfaces, keep the layering.

## 9.5 Error handling end to end

```
DioException / non-2xx
      ↓  ApiClient._mapDioException / _failureFor
Failure (typed)
      ↓  repository — may recover (cache fallback) or annotate
Result<T, Failure>  |  or throw, caught by the controller
      ↓  controller — AsyncValue.error, or a state field
UI     ↓
       ValidationFailure  → inline field errors (fieldErrors map)
       AuthFailure        → sessionController.expire() → /system/session-expired
       NetworkFailure     → offline banner + retry affordance
       TimeoutFailure     → retry affordance
       RateLimitFailure   → "please wait" with a cooldown
       NotFoundFailure    → empty state, not an error toast
       ServerFailure      → generic message + error reporter
```

Two rules the current code does not follow consistently:

- **`AuthFailure` is handled once, centrally.** Today food's `ApiClient` calls `onSessionExpired` and food's `AuthRepositoryImpl` also converts `AuthFailure` into an `ApiResponse.error` string, so the same event has two paths. In the merged app the interceptor is the only place that reacts.
- **`NotFoundFailure` is not an error.** An empty restaurant list and a 404 should both render an empty state. Both apps currently show error toasts for 404s in places.

## 9.6 Caching policy

Food's cache interceptor is opt-in per call (`cacheTtl`). Set a policy so the four modules are consistent:

| Data | TTL | Notes |
|---|---|---|
| CMS pages, legal text, business/feature/fee settings | 24 h | Rarely changes; also unblocks moving 1,313 lines of legal text off-device |
| Categories, cuisines, explore icons | 6 h | |
| Vehicle types, set-prices, goods types | 6 h | Taxi's own comment: the full vehicle catalogue is ~7 MB — cache it, and prefer the slim `/vehicle-map-icons` feed for map art |
| Home banners, offers | 15 min | Merchandising; must be able to change same-day |
| Restaurant list / nearby | 5 min, with `peek()` for instant paint | |
| Restaurant detail, menu | 5 min | |
| Search results | none | |
| Cart, wallet, orders, rides, profile | **never** | Anything the user can mutate, or money |
| Active job / tracking | **never** | Socket + poll |

The "never" row is the important one. Food's cache is keyed on path+query and falls back to the cached copy on *any* network error regardless of age — excellent for a restaurant list, dangerous for a wallet balance.

---

# Chapter 10 — Socket.IO

## 10.1 Current state

### Food — `src/platform/realtime/socket_service.dart` (174 lines)

Connects to `ApiConfig.host` with `auth: {token}`. One connection for the app's lifetime, created by `socketConnectionProvider` and kept alive by `MainAppShell`.

```
Events consumed:
  order_status_update    → OrderSocketEvent.statusUpdate
  order_ready            → orderReady
  location-update        → riderMoved     (parses lat/lng/heading, incl.
                                           legacy boy_lat/boy_lng aliases)
  delivery_drop_otp      → dropOtp
  chat:message           → ChatSocketMessage
  chat:typing            → ChatSocketMessage

Rooms:  emit 'join-tracking' / 'leave-tracking' with an orderId
        _trackedOrderIds re-emitted on connect AND reconnect

Transports: ['polling', 'websocket']   ← deliberate. Comment: some networks
                                          block the initial WS upgrade handshake
Reconnect:  enabled, attempts 1<<30, delay 2 s → max 10 s
Failure:    never throws upward — "sockets are an optimisation, not the contract;
            both tracking and chat must still work by polling"
```

### Taxi — `core/services/socket_service.dart` (125 lines) + `socket_events.dart` (25 lines)

Connects to `ApiConstants.socketUrl` with `auth: {token}`. Server auto-joins the rider's personal room `user:<id>`.

```
Ride room:   ride:join · ride:rejoin-current · ride:joined · ride:state
             ride:status:update / :updated
             ride:driver-location:update / :updated
             ride:driver-route:updated
             ride:message:send / ride:message:new
Dispatch (on user:<id>):
             rideSearchUpdate · rideAccepted · rideCancelled · rideRequestClosed
Errors:      errorMessage

Transports:  ['websocket'] only
Handler registry: _pendingHandlers replayed on every connect
                  → survives logout/login and reconnect
addConnectionListener: list of callbacks, so search AND tracking controllers
                  can both re-join their rooms after a blip
Dispose-before-replace: a dead-but-non-null socket keeps its timers;
                  replacing without disposing leaks one per reconnect
```

## 10.2 Why one connection is not currently possible

- **Different hosts** (`suvio.appzeto.com` vs `taxi.appzeto.com`).
- **Different tokens** (§9.3).
- **Different room models.** Food uses per-order tracking rooms joined by the client. Taxi uses a server-joined personal room for dispatch plus explicit ride rooms.
- **Different event vocabularies.** `order_status_update` vs `ride:status:updated`; snake_case vs colon-namespaced.

So: **a gateway, N connections now, 1 later.**

## 10.3 `SocketGateway`

```dart
class SocketGateway {
  final Map<String, SocketChannel> _channels = {};

  SocketChannel channel(String endpointId);       // create or reuse
  Future<void> connectAll(String Function(String endpointId) tokenFor);
  Future<void> disconnectAll();
  void register(SocketBinding binding);           // from AppModule.socketBinding()
  void pauseAll();                                // app backgrounded
  void resumeAll();                               // app foregrounded
}
```

`SocketChannel` merges the best of both implementations:

| Behaviour | Taken from |
|---|---|
| Handler registry replayed on every (re)connect | Taxi |
| `addConnectionListener` returning a disposer | Taxi |
| Dispose the old socket before replacing it | Taxi |
| Room set re-emitted on connect **and** reconnect | Food |
| `['polling', 'websocket']` transport order | Food |
| Unbounded reconnect, 2 s → 10 s backoff cap | Food |
| Typed broadcast streams per concern | Food |
| Never throws upward | Food (both apps' comments agree) |
| **New:** pause on background after a grace period | neither |
| **New:** per-channel connection state stream for UI | neither |

The two "new" rows matter for a super app specifically: two live websockets held while the app is backgrounded is double the battery cost of either app today, and the user has no indication when realtime is degraded and they are silently on the polling fallback.

## 10.4 Module bindings

```dart
class SocketBinding {
  final String endpointId;
  final String? namespace;                          // post-merge: '/food', '/taxi'
  final Set<String> events;
  final void Function(SocketChannel, Ref) onConnect;
  final void Function(String event, dynamic payload, Ref) onEvent;
}
```

```dart
// FoodModule
SocketBinding(
  endpointId: BackendIds.food,
  events: {'order_status_update', 'order_ready', 'location-update',
           'delivery_drop_otp', 'chat:message', 'chat:typing'},
  onConnect: (ch, ref) {
    for (final id in ref.read(foodTrackedOrdersProvider)) ch.emit('join-tracking', id);
  },
  onEvent: (event, payload, ref) =>
      ref.read(foodSocketRouterProvider).dispatch(event, payload),
);

// TaxiModule
SocketBinding(
  endpointId: BackendIds.taxi,
  events: {...TaxiSocketEvents.rideRoom, ...TaxiSocketEvents.dispatch},
  onConnect: (ch, ref) {
    ch.emit('ride:rejoin-current');            // ← taxi's existing recovery call
    final id = ref.read(activeRideIdProvider);
    if (id != null) ch.emit('ride:join', {'rideId': id});
  },
  onEvent: (event, payload, ref) =>
      ref.read(taxiSocketRouterProvider).dispatch(event, payload),
);
```

**`ride:rejoin-current` is worth noting** — taxi's backend already supports "tell me which ride I should be in", which is exactly the primitive a super app needs after a reconnect. Food has no equivalent (it re-joins from a client-held id set, which is lost on app restart). Ask the backend team for `GET /food/orders/active` semantics or a socket equivalent.

## 10.5 Connection lifecycle

```
app start          gateway created, nothing connected
login              connectAll(tokenFor)  — one connection per distinct endpoint
                   every registered binding's onConnect fires
module entered     binding joins its rooms (idempotent)
network blip       auto-reconnect → handlers replayed → rooms re-joined
                   → connection-state stream flips, UI shows "reconnecting"
app backgrounded   30 s grace, then pauseAll()
app foregrounded   resumeAll(); each binding re-syncs via REST before trusting the socket
logout             disconnectAll(); every channel disposed; rooms cleared
session expired    same as logout
```

Two rules both apps already half-follow, made explicit:

- **REST is the contract; sockets are an accelerator.** Food's comment says this outright. Every tracking screen must poll on a timer as well, and must reconcile on foreground — because a paused socket means missed events, and the user must not see a stale status.
- **Never derive state from a socket event alone if money or status is involved.** An `order_status_update` should trigger a refetch of the order, not blindly overwrite the local status. Food's `order_tracking_viewmodel` (509 lines) largely does this; taxi's ride tracking is more socket-trusting.

## 10.6 Post-merge target

One host, one token, one connection, namespaced events:

```
wss://api.suvio.com/socket.io
  ├─ /food     order_status_update · order_ready · location-update · …
  ├─ /taxi     ride:*  ·  rideAccepted · rideCancelled · …
  ├─ /parcel   parcel:*
  └─ /         user:<id> personal room — cross-module (wallet credited,
                coupon granted, support reply, forced logout)
```

Requests for the backend team (B5):

1. **One auth token accepted on the socket handshake** for all namespaces.
2. **A personal room joined automatically on connect** (taxi already does this — keep it) carrying cross-module events.
3. **A `module` field on every payload**, matching the push discriminator (B4), so one router can dispatch both transports.
4. **A `rejoin-current` equivalent per module**, or one call that returns every active job — this is also what `shared/activity/active_jobs_controller` needs.
5. **Keep `['polling', 'websocket']` support.** Food's transport comment records a real production issue; do not let a reverse-proxy config break the polling fallback.

---

# Chapter 11 — Firebase Notifications

## 11.1 The blocker: two Firebase projects

Confirmed from both `google-services.json` files:

| | Food | Taxi |
|---|---|---|
| `project_id` | `flutterfoodapp-e6742` | `appzet-taxi` |
| `project_number` | `592916974677` | `147333377409` |
| Android apps in the project | `com.fooduser.app`, `com.fooddelivery.app`, `com.foodrestaurant.app` | `com.supertaxi.user`, `com.supertaxi.driver` |
| RTDB | `flutterfoodapp-e6742-default-rtdb` — **actively used** for `active_orders/{orderId}` | none |
| iOS config | **absent** (`AppConstants` has literal `"ios firebase api key"` placeholders) | **absent** (empty strings + TODO) |

**One Android app carries one `google-services.json`, therefore one FCM sender.** This is not negotiable.

### Options

| Option | Work | Risk |
|---|---|---|
| **A. Keep food's project** (`flutterfoodapp-e6742`); add the super-app package id to it | Taxi backend re-credentialed with food's service account; taxi driver app must also move (it shares the taxi project) | Medium — the **driver app** is the catch. Two driver apps and a rider app all need to be on one project |
| **B. Keep taxi's project** (`appzet-taxi`) | Food backend re-credentialed; **RTDB recreated** and food's dispatch writer repointed; restaurant + delivery-partner apps move | Higher — RTDB migration touches live order tracking |
| **C. New project** `suvio-superapp`; migrate everything | Both backends re-credentialed, RTDB recreated, all five apps re-registered | Highest up-front, cleanest end state |

**Recommendation: A**, with a caveat. Food's project already hosts three apps and the RTDB that live order tracking depends on; moving *to* it is less invasive than moving *away* from it. The caveat is that the taxi **driver** app (`com.supertaxi.driver`) must move too, since driver↔rider push and the dispatch socket assume one project — and that app is out of scope for this document. Confirm before committing.

Whichever is chosen: **generate `firebase_options.dart` with the FlutterFire CLI.** Both apps currently hand-write `FirebaseOptions` from constants, and food's fallback path exists precisely because the default init sometimes fails. A generated options file removes that whole failure mode.

## 11.2 Current implementations

### Food — `push_service.dart` (457 lines)

Genuinely complete. Covers:

- `ensureFirebaseInitialized()` with an explicit-`FirebaseOptions` fallback if the default init fails
- `@pragma('vm:entry-point')` background handler that **re-initialises Firebase in the isolate** (required — the isolate does not inherit app init)
- Android channel `high_importance_channel` at `Importance.max`, created at runtime
- Foreground: `onMessage` → `flutter_local_notifications.show()` with the FCM data as a JSON payload
- Background tap: `onMessageOpenedApp`
- Terminated: `getInitialMessage()` on first frame
- Local-notification tap → parses the JSON payload → deep link
- Token lifecycle: `getToken`, `onTokenRefresh`, save locally (secure storage) **and** to the backend
- `registerToken(user:)` on login; `unregisterToken()` on logout doing all four things — backend record removed, `deleteToken()`, local cache cleared, and `cancelAll()` so the outgoing session's tray notifications go away
- `performAppStartCheck()` reconciling stored vs. current token on launch
- A debug summary block printing every step's outcome
- **Deep links leave via a callback**, so the service never touches navigation

Its one coupling to food: `PushDeepLink.isOrderEvent` hardcodes `order_` / `delivery_` / `payment_success` / `delivery_accepted`.

Two gaps: **no iOS initialisation settings at all** (`InitializationSettings(android: …)` only), and it is `unawaited`-heavy in ways that make failures silent.

### Taxi — `notification_service.dart` (98 lines)

Thin. Registers the background handler, initialises local notifications **with iOS `DarwinInitializationSettings`** (which food lacks), creates channel `ride_updates` at `Importance.high`, requests permission, shows foreground notifications, forwards taps. Its background handler only logs.

One behaviour worth keeping: `_checkAudioForNotification` inspects `type`/`status`/`title`/`body` for "start"/"ongoing"/"complete"/"end" and plays a trip-started or ride-ended sound. Crude string matching, but the *feature* is good.

Routing lives in `main.dart`:
```dart
if (type == 'no_drivers_found') → go('/home/no-driver')
else if (rideId != null)        → push('/ride/tracking/$rideId')
else                            → push('/notifications')
```
with a good comment explaining why a cancelled search must not open a dead tracking screen.

## 11.3 Manifest conflicts

| Key | Food | Taxi | Merged |
|---|---|---|---|
| `default_notification_channel_id` | `high_importance_channel` | `ride_updates` | **One default.** Create a `superapp_default` channel and let per-message `android_channel_id` override it |
| `default_notification_icon` | `@mipmap/ic_launcher` | not set | Set it; use a proper monochrome notification icon, not the launcher icon |
| `com.google.android.geo.API_KEY` | `AIzaSyCLHQ…` | `AIzaSyArBb…` | **One key** — see §11.7 |
| `FlutterFirebaseMessagingService` | explicitly declared | not declared | Not required (the plugin's manifest merges it); harmless to keep |
| `ScheduledNotificationReceiver` + boot receiver | declared | not declared | Keep food's — needed for scheduled notifications |
| `POST_NOTIFICATIONS` | declared | declared, with a good comment about API 33 | Keep |

**The single-default-channel constraint is the important one.** FCM only applies `default_notification_channel_id` when a *notification* message arrives with no explicit channel. The fix is for the backend to set `android_channel_id` per message type — which then also delivers the per-module notification settings from [Ch. 6 §6.5](05-shared-components.md).

## 11.4 Merged design

```
                     FCM (one project, one sender)
                                │
                   ┌────────────┴────────────┐
                   ▼                         ▼
        foreground onMessage         background / terminated
                   │                         │
                   ▼                         ▼
            PushService  ────────►  PushMessage (unified envelope)
                   │                         │
       shows a local notification            │  (tap)
       on the channel resolved by            ▼
       PushChannels.forModule(m)        PushRouter
                                             │
                                  ModuleRegistry.resolvePush()
                                    first module to claim wins
                                             │
                                             ▼
                                  router.push(PushRoute.location)
```

```dart
class PushMessage {
  final ModuleId? module;        // data['module'] — REQUEST B4
  final String type;             // data['type']
  final String? title, body;
  final Map<String, dynamic> data;
  final PushOrigin origin;       // foreground | background | terminated

  String? string(String k);
  num?    number(String k);

  factory PushMessage.from(RemoteMessage m, PushOrigin origin) => PushMessage(
    module: ModuleId.tryParse(m.data['module']?.toString()),
    type:   (m.data['type'] ?? '').toString(),
    title:  m.notification?.title ?? m.data['title']?.toString(),
    body:   m.notification?.body  ?? m.data['body']?.toString(),
    data:   Map<String, dynamic>.from(m.data),
    origin: origin,
  );
}
```

### Channels

```dart
class PushChannels {
  static const foodOrders = AndroidNotificationChannel('food_orders',
      'Food orders', importance: Importance.max);
  static const rideUpdates = AndroidNotificationChannel('ride_updates',
      'Ride updates', importance: Importance.max);
  static const parcelUpdates = AndroidNotificationChannel('parcel_updates',
      'Parcel updates', importance: Importance.max);
  static const chat = AndroidNotificationChannel('chat',
      'Messages', importance: Importance.high);
  static const promotions = AndroidNotificationChannel('promotions',
      'Offers & promotions', importance: Importance.defaultImportance);
  static const account = AndroidNotificationChannel('account',
      'Account & wallet', importance: Importance.high);
  static const fallback = AndroidNotificationChannel('superapp_default',
      'General', importance: Importance.high);
}
```

Six channels instead of one. This is what lets a user mute promos without missing "your driver has arrived", and it is a Play-Store-visible quality signal.

### The background handler

One `@pragma('vm:entry-point')` top-level function. Food's version wins (it re-initialises Firebase, which taxi's does not). It must stay minimal — it runs in a bare isolate with no `ProviderScope`, so it cannot resolve modules. Keep it to: init Firebase, parse the envelope, optionally show a local notification, optionally write a "pending deep link" to secure storage for the next foreground to pick up.

**Do not try to route from the background isolate.** Food's current handler correctly only logs.

## 11.5 Push payload contract — request to the backend

The concrete asks (B4), for both backends until they merge:

```json
{
  "notification": { "title": "…", "body": "…" },
  "data": {
    "module":  "food",                      // food | taxi | parcel | rental | account
    "type":    "order_out_for_delivery",
    "jobId":   "665f…",                     // one canonical id field
    "deepLink":"/food/orders/665f…/track",   // server-resolved, client-verified
    "android_channel_id": "food_orders"
  },
  "android": { "notification": { "channel_id": "food_orders" } }
}
```

Four points:

1. **`module` is mandatory.** Without it the router guesses from `type` prefixes — and food already uses `delivery_` for *food* delivery, which is genuinely ambiguous against the parcel module.
2. **One id field.** Food currently sends both `orderId` and `orderMongoId`, and `PushDeepLink.trackableOrderId` prefers the Mongo id because that is what `GET /food/orders/:id` expects. That ambiguity should not survive the merge.
3. **`deepLink` server-side, validated client-side.** Convenient, but the client must confirm the route exists and that the module is enabled — never `push()` a server string blindly.
4. **Legacy tolerance.** Food's backend currently sends `link: '/food/user/orders/<id>'` — an API path, not an app route. The router must tolerate the old shape for at least one release cycle.

## 11.6 Token registration

| | Food | Taxi |
|---|---|---|
| Save | `POST /fcm-tokens/mobile/save` | `POST /users/fcm-token` (with `platform`) |
| Remove | `POST /fcm-tokens/remove` | none |
| On login | `registerToken(user:)` via a reactive `ref.listen` on auth | in `AuthController` |
| On logout | full four-step unregister | none |
| On refresh | `onTokenRefresh` → save locally + backend | none |
| On launch | `performAppStartCheck()` reconciles | none |

Food's lifecycle is complete; taxi's leaks (a device stays registered to a logged-out account, so the next user of that phone gets the previous user's ride notifications — a real privacy issue).

Merged: food's lifecycle, one `PushTokenSink` abstraction so it can write to one endpoint now and two during the transition:

```dart
abstract interface class PushTokenSink {
  Future<bool> save(String token, {UserDto? user});
  Future<void> remove(String token);
}
// MultiPushTokenSink fans out to both backends; collapses to one post-merge.
```

**Both backends must be told about the same token**, or ride pushes stop working after a food-only login. Easy to miss; hard to debug.

## 11.7 Google Maps API key

Not strictly notifications, but the same single-value-per-manifest problem:

| | Food | Taxi |
|---|---|---|
| Key | `AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak` | `AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc` |
| In manifest | hardcoded **and** a `MAPS_API_KEY` manifest placeholder exists in `build.gradle.kts` | hardcoded |
| Also used for | Geocoding REST (`AppConstants.mapKey`) | `geocoding` plugin (no key needed) |

Merged app: **one key**, restricted to the merged package id + SHA-1, with Maps SDK for Android/iOS + Geocoding + Places enabled. Supply it via food's existing `manifestPlaceholders["MAPS_API_KEY"]` mechanism and `--dart-define`, and **remove both hardcoded literals from source control** — they are currently committed in plaintext in two manifests and two Dart files.

Also budget for it: consolidating two apps' traffic onto one key doubles the billed volume against one quota. The geocode cache from taxi's `location_service` ([Ch. 3](03-file-migration-map.md)) is what keeps that affordable, which is why it is on the keep list.
