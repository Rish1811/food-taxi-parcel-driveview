# Chapters 12–15 — Maps, Search, Wallet, Activity

---

# Chapter 12 — Maps

## 12.1 Current state

| | Food | Taxi |
|---|---|---|
| Plugin | `google_maps_flutter: ^2.18.0` | `google_maps_flutter: ^2.9.0` |
| Files using maps | 3 | **12** |
| Map style | `core/utils/map_styles.dart` — 26 lines | `core/theme/app_map_style.dart` — **157 lines** |
| Markers | inline in `live_tracking_map.dart` | `marker_icon_loader.dart` 74 · `vehicle_marker_icons.dart` 89 · `route_marker_helper.dart` 107 |
| Polylines | `flutter_polyline_points` (2 files) | `polyline_decoder.dart` 52 · `route_polyline_service.dart` 118 |
| Main map screen | `orders/widgets/live_tracking_map.dart` — **894 lines** | `ride_tracking_screen.dart` 658 · `home_screen.dart` 1,380 · `map_picker_screen.dart` 254 |
| Live source | **Firebase RTDB** `active_orders/{orderMongoId}` + socket `location-update` | socket `ride:driver-location:updated` + `ride:driver-route:updated` |
| Geocoding | Google REST via Dio | `geocoding` plugin |
| Map key | `AIzaSyCLHQ…` | `AIzaSyArBb…` |

**Taxi has the better toolkit (~600 lines of reusable helpers); food has the better single screen but it is monolithic.** Neither shares anything with the other, so both have independently solved marker rotation, camera fitting, and polyline drawing.

An important asymmetry: food's live tracking reads from **Firebase RTDB**, taxi's from **sockets**. The RTDB node carries `polyline`, `lat`, `lng`, `restaurantLat/Lng`, `customerLat/Lng`, `status` — i.e. the server pre-computes the route so the client never calls the Directions API. Taxi receives `ride:driver-route:updated` over the socket for the same purpose. Two transports, one concept.

## 12.2 Merged design

```
core/maps/
├── map_style.dart              ← taxi's 157-line style, light + dark
├── marker_factory.dart         ← taxi's 3 marker utils merged
│     • fromAsset(path, size)   with a bitmap cache (critical — see §12.4)
│     • vehicle(type, heading)
│     • pin(kind)               pickup · drop · restaurant · customer · store
├── polyline_service.dart       ← taxi's decoder + route service
│     • decode(String)          zero-cost, no API call
│     • fromDirections(...)     only if a client-side Directions call is needed
├── map_camera.dart             NEW — extracted from both tracking screens
│     • fitBounds(points, padding)
│     • follow(target, zoom, bearing)
│     • animateSmoothly(from, to, duration)
└── live_track_controller.dart  NEW — the shared abstraction
```

### `LiveTrackController` — the one thing worth building new

Both apps implement the same behaviour: *an entity is moving toward a destination; interpolate its position, rotate its marker to its heading, keep the camera sensible, draw the remaining route.* It is ~400 lines in food's `live_tracking_map.dart` and ~250 in taxi's `ride_tracking_screen.dart`.

```dart
class LiveTrackConfig {
  final LatLng origin, destination;
  final Stream<TrackPoint> positions;       // RTDB or socket — the controller
                                            // does not care which
  final String? encodedRoute;
  final MarkerSpec movingMarker;
  final Duration interpolation;             // smooth between sparse updates
  final CameraMode cameraMode;              // follow | fitAll | free
}

class TrackPoint {
  final double lat, lng;
  final double heading;
  final DateTime at;
}
```

Food's stream comes from `OrderRtdbDataSource.watchActiveOrder(id)` mapped to `TrackPoint`; taxi's from the socket binding. Both then get: marker interpolation, heading rotation, camera modes, route drawing, and "driver is X min away" — one implementation, tested once.

The three tracking screens (food order, taxi ride, parcel job) become thin: a `LiveTrackController` plus their own bottom sheet.

## 12.3 Reusable widgets

```
design_system/components/map/
├── app_map.dart                GoogleMap + style + dark-mode + padding + defaults
├── map_pin_overlay.dart        centre pin for the address picker
├── map_fab_column.dart         ← taxi's map_fab.dart (30 lines)
├── tracking_bottom_sheet.dart  draggable sheet over a map (both apps hand-roll this)
└── eta_chip.dart               "5 min away"
```

`AppMap` matters more than it looks: it is the one place that applies the style JSON, sets `padding` so the Google logo is not covered (a Maps ToS requirement both apps get wrong in places), handles the light/dark style swap, and sets `liteModeEnabled` for non-interactive previews.

`map_picker_screen.dart` (taxi, 254 lines) becomes `shared/address/presentation/map_picker_screen.dart` and serves food's address editor too — food currently has no map picker at all despite a 1,436-line address screen.

## 12.4 Performance — the part that will bite

Maps are the heaviest thing in either app, and a super app can have two map contexts alive.

| Issue | Evidence | Fix |
|---|---|---|
| **`markerbike.png` is 2.2 MB** | `flutter_taxi_user/assets/` | Re-encode to WebP at the actual rendered size. Two markers are already `.webp` at ~200 KB, so the intended size is known |
| **Marker bitmaps rebuilt per frame** | both apps decode assets inside update paths | `MarkerFactory` caches `BitmapDescriptor`s by (asset, size, heading-bucket). Bucket heading to 5° — 72 cached rotations, not one per update |
| **Two `GoogleMapController`s alive** | new to the merged app | `AppMap` disposes on route exit; module `ProviderScope` teardown enforces it |
| **Impeller disabled** | food's manifest sets `EnableImpeller=false` for a `video_player`/Vulkan bug | Test taxi's maps with Impeller off — this has never been exercised. See [Ch. 16 §16.9](10-performance-and-app-size.md) |
| **~7 MB vehicle catalogue** | taxi's own comment on `/users/vehicle-map-icons`: the slim feed exists "instead of the ~7MB full catalog" | Always use the slim feed for map art; cache it 6 h |
| **Geocoding on every GPS tick** | taxi's `location_service` comment (in Hinglish) says "GPS stream pe geocode mat chalao" | Keep taxi's grid cache + 3 s throttle + <50 m skip. This is also a billing control |
| **Duplicate map keys → doubled quota** | two keys today, one after merge | Budget for it; the cache above is the mitigation |

---

# Chapter 13 — Search

## 13.1 The brief says "unified search entry". It should be a qualified yes.

| | Food search | Taxi "search" |
|---|---|---|
| File | `search_screen.dart` **1,077 lines** | `search_destination_screen.dart` **926 lines** |
| Controller | `search_viewmodel.dart` 156 + `search_state.dart` 58 + `search_service.dart` 190 | `ride_search_controller.dart` 216 + `ride_search_state.dart` 83 |
| Endpoint | `GET /food/search/unified` | place autocomplete (Google) + `/users/service-locations` |
| Finds | restaurants, dishes, categories, brands | **addresses** |
| Recents | `search_local_datasource.dart` 49 | `recent_searches_provider.dart` 40 (Hive) |
| Voice | `voice_search_dialog.dart` 308 + `speech_service.dart` 128 | none |
| Route | `/search?q=` | `/home/search` (with `/search` redirecting to it) |
| Result action | navigate to content | **return a value into a booking funnel** |

These are not the same feature. Food's search is content discovery. Taxi's is a **modal picker inside a multi-step funnel** — it returns a destination to the previous screen and has no meaning outside a booking. Merging them into one screen would be a UX regression and would make the booking funnel harder, not easier.

## 13.2 What to unify, and what not to

**Unify:**

- **One search entry point** at `/search` — a global search surface reachable from the hub and from each module.
- **One `SearchSource` contract** so modules contribute result types.
- **One recent-searches store**, module-tagged (food's 49-line datasource + taxi's 40-line Hive provider → one `RecentSearchesStore`).
- **One search field component** (`design_system/components/inputs/search_field.dart`, from taxi's `app_search_bar.dart`).
- **Voice search available to every source** — food's 308-line dialog + `SpeechService` become shared, so "book a cab to the airport" is reachable.

**Do not unify:**

- Taxi's destination picker. It stays `modules/taxi/presentation/booking/destination_search_screen.dart`, reachable at `/taxi/destination`, returning an `AddressDto`. It shares the search *field* and the *recents store*, nothing else.
- Parcel's address steps, for the same reason.

## 13.3 `SearchSource`

```dart
abstract interface class SearchSource {
  ModuleId get module;
  String get sectionTitle;             // "Restaurants" · "Dishes" · "Places"
  int get priority;                    // ordering within the results list
  int get maxResults;

  Future<List<SearchHit>> query(String q, SearchContext ctx);
  Widget buildTile(BuildContext c, SearchHit hit);
}

class SearchHit {
  final ModuleId module;
  final String id, title;
  final String? subtitle, imageUrl;
  final String route;                  // where tapping goes
  final Map<String, dynamic> payload;  // passed as `extra` for a warm push
  final double relevance;
}

class SearchContext {
  final LatLng? near;
  final String? zoneId;
  final Set<ModuleId> restrictTo;      // empty = all enabled modules
}
```

Contributions:

| Module | Sources |
|---|---|
| Food | `RestaurantSearchSource`, `DishSearchSource` (both from `/food/search/unified`) |
| Taxi | `PlaceSearchSource` — only when invoked *inside* the taxi module (`restrictTo`) |
| Parcel | none — its addresses come from the shared picker |
| Rental | `RentalVehicleSearchSource` |
| Shared | `RecentSearchSource`, `ActivitySearchSource` (search past orders and rides — "that biryani place I ordered from in March") |

`ActivitySearchSource` is a genuine super-app-only feature: neither app can search history today, and it is cheap once the activity feed exists.

## 13.4 Merged search screen

```
┌ /search ─────────────────────────────────┐
│  [🔍 Search for food, places, rides  🎤] │  ← shared SearchField + voice
├──────────────────────────────────────────┤
│  Recent          ← RecentSearchesStore,  │
│                    module-tagged chips   │
├──────────────────────────────────────────┤
│  Restaurants (3)      → /food/…          │  FoodModule
│  Dishes (5)           → /food/dishes/…   │  FoodModule
│  Past orders (2)      → /food/orders/…   │  shared/activity
│  Rentals (1)          → /rental/…        │  RentalModule
└──────────────────────────────────────────┘
```

Behaviour rules:

- **Sources are queried in parallel and rendered as they arrive**, sorted by `priority` then `relevance`. One slow source must not block the rest — food's search is a network call, recents are local and should appear instantly.
- **Debounce 300 ms**, cancel in-flight queries on new input. Food's viewmodel does this; taxi's does too. Keep it in the shared controller so it is done once.
- **Empty query shows recents + trending**, not a blank screen.
- **`restrictTo`** lets the same screen be a module-scoped search: entering search from inside `/food` restricts to food sources, and shows a "search everything" affordance.

## 13.5 Files

| From | Lines | Action |
|---|---|---|
| `F: search_screen.dart` | 1,077 | SPLIT → `shared/search/presentation/search_screen.dart` (shell, ~300) + food result tiles |
| `F: search_viewmodel.dart` + `search_state.dart` | 214 | SPLIT → shared controller + `FoodSearchSource` |
| `F: search_service.dart` | 190 | SPLIT → `shared/search/data/search_repository.dart` + food source |
| `F: search_remote_datasource.dart` | 83 | MOVE → `modules/food/api/datasources/` |
| `F: search_local_datasource.dart` | 49 | MERGE → `shared/search/data/recent_searches_store.dart` |
| `F: search_result.dart` | 55 | REBUILD → `SearchHit` (module-tagged, extensible) |
| `F: voice_search_dialog.dart` | 308 | MOVE → `shared/search/presentation/` |
| `T: search_destination_screen.dart` | 926 | **KEEP** → `modules/taxi/presentation/booking/` |
| `T: ride_search_controller.dart` + `_state.dart` | 299 | MOVE+NS → `modules/taxi/application/destination_search_controller.dart` |
| `T: recent_searches_provider.dart` | 40 | MERGE → shared recents store |

---

# Chapter 14 — Wallet

## 14.1 The rule that governs this chapter

**Never display the sum of two balances as one balance.**

If food holds ₹200 and taxi holds ₹150, showing "₹350" is wrong in three ways: the user cannot spend ₹350 on either side; a ₹250 food order will fail after the UI said it would succeed; and two concurrent debits against two ledgers cannot be reconciled. This is a financial correctness issue, not a UX preference.

Everything below follows from that.

## 14.2 Current state

| | Food | Taxi |
|---|---|---|
| Model | `wallet_model.dart` **378 lines** | `wallet_transaction_model.dart` **32 lines** |
| Contents | balance, cashback ledger, refund history, cashback settings | id, type, amount, description, createdAt, status |
| Screen | `wallet_screen.dart` **926 lines** — the better display | `wallet_screen.dart` 128 + `topup_sheet.dart` 113 |
| Balance | `GET /food/user/wallet` | `GET /users/wallet` |
| Add money | **none** | `/users/wallet/topup`, Razorpay order+verify, PhonePe order+status |
| Transfer | none | `/users/wallet/transfer`, `/transfer/driver` |
| Cashback | `/food/user/cashback` + `/food/admin/cashback-settings/public` | none |
| Refunds | `/food/user/refunds` | none |
| On the user object | `UserModel.walletBalance` (defaults to 0, "the wallet endpoint supplies the real number") | none |

Each app has exactly what the other lacks. Food can show a rich ledger and cannot add money; taxi can add money and shows a flat list.

## 14.3 Three possible backend answers (B6), and the client design for each

### B6-a: one ledger — the correct answer

One `wallet` collection, one balance, one transaction stream, `module` tagged per entry.

```
shared/wallet/
├── data/
│   ├── wallet_repository.dart      balance · transactions(cursor) · topup · verify
│   └── wallet_dto.dart             ← food's 378-line model, + module tags
├── application/
│   ├── wallet_controller.dart      AsyncNotifier<WalletState>   APP SCOPE
│   └── wallet_state.dart
└── presentation/
    ├── wallet_screen.dart          ← food's 926-line UI
    ├── topup_sheet.dart            ← taxi's 113-line sheet
    └── transaction_list.dart       filter chips: All · Food · Rides · Parcel
                                    · Cashback · Refunds · Top-ups
```

```dart
class WalletTransactionDto {
  final String id;
  final ModuleId? module;              // null = wallet-level (top-up, transfer)
  final TxnKind kind;                  // debit · credit · cashback · refund
                                       // · topup · transfer
  final int amountPaise;               // ← integer paise. NEVER double for money
  final String description;
  final String? jobId;                 // order / ride / parcel reference
  final DateTime createdAt;
  final TxnStatus status;
}
```

Two details worth insisting on:

- **Integer paise, not `double`.** Both apps currently parse amounts as `double` (`double.tryParse('${json['amount']}')`). Floating point for currency accumulates error and produces `₹349.99999`. Money is an integer count of the smallest unit, formatted for display only.
- **Balance is read, never computed.** The client shows what the server says. Optimistic UI on a wallet debit is not worth the bug class it introduces.

### B6-b: two ledgers with a server-side transfer bridge

Workable. The client shows **one primary balance** (the unified one, or the one belonging to the active module's payment context) and treats the other as a transferable source:

```
┌─ Wallet ──────────────────┐
│  ₹200.00                  │  ← primary, spendable
│  [ Add money ]            │
│  ⓘ ₹150.00 in Rides       │  ← secondary, with a "Move to main" action
│     [ Transfer → ]        │
└───────────────────────────┘
```

Explicit, honest, and it maps onto taxi's existing `/users/wallet/transfer` endpoint. Not pretty, but it never lies.

### B6-c: two independent ledgers, no bridge

Then there is no "one wallet", and the UI must not claim one. Show two cards under one screen, each with its own balance and top-up. Say which is which. **Do not sum them.**

**Recommend B6-a.** It is the only answer where "one wallet" is a true statement, and it is a backend-side consolidation that the client cannot work around.

## 14.4 Payment integration

Every debit flows through a `PaymentIntent` carrying `module` ([Ch. 6 §6.6](05-shared-components.md)), which is what makes attribution work:

```
food checkout    → PaymentIntent(module: food,   purpose: 'food_order',    jobId: orderId)
ride completion  → PaymentIntent(module: taxi,   purpose: 'ride_fare',     jobId: rideId)
parcel booking   → PaymentIntent(module: parcel, purpose: 'parcel_fare',   jobId: jobId)
rental advance   → PaymentIntent(module: rental, purpose: 'rental_advance', jobId: bookingId)
wallet top-up    → PaymentIntent(module: null,   purpose: 'wallet_topup')
subscription     → PaymentIntent(module: null,   purpose: 'subscription')
```

`WalletAdapter` is one of the payment adapters, so "pay with wallet" is not a special case scattered across four checkout flows.

Two things to preserve from the existing code:

- **Food's Razorpay branding config.** `AppConstants.brandName` / `brandLogoUrl` exist because without them Razorpay's sheet shows the legal entity ("SWITCHEATS PRIVATE LIMITED") instead of the consumer brand. Keep it, and consider making the brand follow the active module.
- **Taxi's verify-after-pay pattern.** Taxi has explicit `/verify` endpoints for wallet, bus, pooling, and rental advance. Food has `/food/orders/verify-payment`. Never trust the client-side Razorpay success callback alone — always round-trip to the server verify endpoint before treating money as received. Both apps do this; make it a rule in the shared adapter so no future module forgets.

## 14.5 Wallet in the hub

Balance is app-scope state, so it is cheap to show everywhere:

```
/hub          balance chip in the header
/food/cart    "Use ₹200 wallet balance" toggle
/taxi/confirm payment-method row with the balance inline
/wallet       full screen
```

Refresh triggers: app foreground, `AppEvent.paymentSucceeded`, `AppEvent.jobCompleted`, and a socket `wallet:credited` on the personal room (a B5 request — it is how a cashback credit appears without a pull-to-refresh).

---

# Chapter 15 — Activity (unified order history)

## 15.1 Current state — four history screens

| Screen | App | Lines | Endpoint |
|---|---|---|---|
| `orders_screen.dart` | Food | **973** | `GET /food/orders` |
| `ride_history_screen.dart` | Taxi | 429 | `GET /rides` |
| `delivery_history_screen.dart` | Taxi | 56 | `GET /deliveries` |
| `rental_history_screen.dart` | Taxi | 181 | `GET /users/rental-bookings` |
| `recent_activity_card.dart` | Taxi | 320 | (widget) |

Plus `orders_viewmodel.dart` (237) and `ride_history_controller.dart` (69) + `ride_history_state.dart` (42).

**1,639 lines of screen code doing the same job four times.**

## 15.2 Merged design

```
shared/activity/
├── data/
│   ├── activity_repository.dart     merges sources, owns pagination
│   └── activity_item.dart           the row model
├── application/
│   ├── activity_controller.dart     AsyncNotifier<ActivityFeed>
│   ├── activity_filter.dart         tab + date range + module set
│   └── active_jobs_controller.dart  APP SCOPE — drives the floating cards
└── presentation/
    ├── activity_screen.dart         shell + tab bar (~250 lines)
    └── widgets/
        ├── activity_row.dart        generic fallback row
        └── active_job_card.dart     ← from food's floating_active_order_card
```

```dart
class ActivityItem {
  final ModuleId module;
  final String id;
  final ActivityKind kind;          // foodOrder · ride · parcel · rentalBooking
  final DateTime createdAt;
  final ActivityStatus status;      // pending · active · completed · cancelled
  final String title;               // "Domino's Pizza" · "Andheri → BKC"
  final String? subtitle, imageUrl;
  final int? amountPaise;
  final String detailRoute;         // '/food/orders/x' | '/taxi/rides/y'
  final String? trackRoute;         // non-null only while active
  final List<ActivityAction> actions;   // Reorder · Rebook · Rate · Invoice · Help
  final Map<String, dynamic> raw;   // for the module's own tile renderer
}

abstract interface class ActivitySource {
  ModuleId get module;
  Future<ActivityPage> fetch({String? cursor, ActivityFilter? filter});
  Widget? buildTile(BuildContext c, ActivityItem item);   // null → generic row
  Future<void> handleAction(ActivityAction a, ActivityItem i, Ref ref);
}
```

Screen:

```
┌ /activity ───────────────────────────────────────┐
│  All   Food   Rides   Parcel   Rental            │  ← tabs, from enabled modules
├──────────────────────────────────────────────────┤
│  ▸ ACTIVE                                        │
│    🛵 Order #4821 · Out for delivery  [Track]    │  ← FoodModule tile
│    🚕 Ride to BKC · Driver arriving   [Track]    │  ← TaxiModule tile
├──────────────────────────────────────────────────┤
│  Today                                           │
│    🍔 Domino's · ₹450 · Delivered  [Reorder][Rate]│
│  Yesterday                                       │
│    🚕 Andheri → BKC · ₹280 · Completed [Rebook]  │
│    📦 Parcel to Powai · ₹120 · Delivered         │
└──────────────────────────────────────────────────┘
```

## 15.3 Pagination — the part that decides the backend request (B7)

This is the crux, and it is why B7 is on the blocker list.

### If the backend provides `GET /activity?cursor=&modules=&kind=`

Correct, simple, fast. One request per page, server-side sort by `createdAt`, one cursor. The client is a list view.

### If the client must fan out to N endpoints and merge

Client-side merge of independently-paginated sources **cannot be made correct in general**, and it is worth being precise about why: if you request 20 from each of four sources and sort the 80 by date, the oldest item in your merged window may be newer than an unfetched item from another source. You cannot know you have the true next-oldest without over-fetching unboundedly.

The workable approximation:

```dart
// K-way merge with per-source lookahead buffers
class MergingActivityRepository {
  // Keep a buffer per source. Emit the newest across buffers.
  // Refill a source's buffer when it drops below a watermark.
  // A page is "complete" only when every source has either
  // contributed or is exhausted for that time window.
}
```

Practical constraints: request by **time window** rather than count (`?since=&until=`), which makes the merge exact within the window; or accept approximate ordering and be explicit about it in the UI (group by day, sort within day — day boundaries make small mis-orderings invisible).

**Recommend requesting B7: `GET /activity`.** Grouping by day hides a lot, but "Reorder" on the wrong item because pagination shuffled the list is a real bug, and no amount of client cleverness removes it.

## 15.4 Active jobs — the genuinely new state

Neither app has ever had to handle a food order *and* a ride in flight at once. In the merged app that is normal.

```dart
class ActiveJobsController extends Notifier<List<ActiveJob>> {
  // APP SCOPE — survives module switches, which is the whole point.
  // Sources: each module's active-job endpoint + socket updates.
  // Refresh on: foreground, AppEvent.jobStarted/jobCompleted, push arrival.
}
```

Rendering rules in `app_shell.dart`:

| Active jobs | UI |
|---|---|
| 0 | nothing |
| 1 | full floating card (food's existing `FloatingActiveOrderCard`, 248 lines) |
| 2 | two stacked compact cards |
| 3+ | one pill: "3 active — view all" → `/activity` |

Where the card shows: on `/hub` and on shared screens. **Not** inside a module that is already showing its own tracking — food's `MainAppShell` already implements exactly this suppression logic (`opacity: isHome ? 1.0 : 0.0`), which generalises.

Backend requests: an endpoint per module returning active jobs (taxi has `GET /rides/active/me`, food needs the equivalent), or ideally one `GET /activity/active`. Note taxi's socket already has `ride:rejoin-current`, which is the same primitive over a different transport.

## 15.5 Actions

| Action | Handled by | Notes |
|---|---|---|
| Reorder | `FoodActivitySource` | Food's `orders/utils/reorder.dart` (64) + the `/buy-again` route already exist |
| Rebook | `TaxiActivitySource` | Pre-fill the booking funnel from the past ride |
| Rate | module source | Food's `rate_order_sheet.dart` (343); taxi's `rating_review_screen.dart` (757) |
| Invoice / receipt | shared | Neither app has this. Wallet + activity make it possible |
| Help with this order | `shared/support` | `ChatContext.job(module, jobId, peer)` |
| Track | module | `trackRoute` |

`handleAction` on the source keeps the activity screen from knowing what a reorder is.

## 15.6 File impact

| Item | Before | After |
|---|---|---|
| Food orders screen + viewmodel | 1,210 | ~150 (source + tile) |
| Ride history screen + controller + state | 540 | ~150 |
| Delivery history | 56 | ~80 |
| Rental history | 181 | ~100 |
| Recent activity card | 320 | ~200 (shared) |
| Activity shell + controller + repo | — | ~600 |
| **Total** | **2,307** | **~1,280** |

~1,000 lines saved, and the result does things none of the four screens can: cross-module chronological view, search over history, receipts, and a coherent active-job display.

**Gated on B7.** Without a unified endpoint this still works, but the pagination is approximate — and that limitation should be a conscious product decision, not a surprise discovered in QA.
