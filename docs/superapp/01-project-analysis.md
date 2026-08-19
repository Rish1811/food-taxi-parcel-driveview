# Chapter 1 — Project Analysis

Everything here is measured from the source tree at `C:\Users\rishi\OneDrive\Desktop\Flutter_food\food+taxi`. No estimates unless labelled.

---

## 1.1 Repository layout as found

```
food+taxi/
├── Food_user/
│   └── flutter-food-user-application/        ← the food app (has .git)
│       ├── lib/                              212 dart files, 51,724 lines
│       ├── assets/                           12 MB
│       ├── android/  ios/  web/  test/
│       ├── backend/food-backend/             EMPTY
│       ├── l10n.yaml
│       ├── BACKEND_CHANGES.md  GUIDELINES.md  SUVIO_QUICK_MASTER_PROMPT.md
│       └── pubspec.yaml                      name: food_user_application
└── flutter_taxi_user/                        ← the taxi app
    ├── lib/                                  173 dart files, 23,083 lines
    ├── assets/                               17 MB (flat, 33 root-level PNGs)
    ├── android/  ios/  web/  linux/  macos/  windows/  test/
    ├── backend/taxi-new/Backend/             Node/Express, mounted at /api/v1
    ├── Taxi_userapp.docx
    └── pubspec.yaml                          name: taxiuser
```

Two notes before anything else:

- **The food backend folder is empty.** Only the taxi backend is present in this workspace. The food API surface had to be reconstructed from `lib/src/core/config/api_config.dart`, which is complete enough to be authoritative about paths.
- **Taxi has desktop platform folders** (`linux`, `macos`, `windows`) that food does not. They are unused scaffolding; drop them in the merge.

---

## 1.2 Food app — structure

Layered, roughly clean-architecture-shaped, everything under `lib/src/`:

```
lib/
├── main.dart                          24    Firebase init → background handler → runApp
├── generated/l10n/                    464   app_localizations.dart + _en.dart
├── l10n/                              (app_en.arb)
└── src/
    ├── food_user_application.dart     120   root widget: ScreenUtilInit → MaterialApp.router
    ├── core/                           11 files,   859 lines
    │   ├── config/api_config.dart      102   ApiConfig + ApiPaths (all /food/* paths)
    │   ├── constants/app_constants.dart 90   hosts, Firebase keys, map key, brand
    │   ├── error/failures.dart          46   typed Failure hierarchy
    │   ├── network/api_client.dart     354   ★ the strongest single file in either app
    │   ├── network/api_response.dart     8
    │   ├── storage/token_storage.dart   64   secure access+refresh pair, in-memory cached
    │   └── utils/                            haptics, map_styles, 2 audio players
    ├── data/                           32 files, 4,588 lines
    │   ├── datasources/                10   account, address, auth, catalog, chat,
    │   │                                    favorites, order, order_rtdb, search×2
    │   ├── models/                     16   order_model 747, wallet_model 378,
    │   │                                    restaurant_model 294, food_model 164 …
    │   └── repository/                  6   auth, favorites, restaurant, search,
    │                                        store99, wallet
    ├── domain/                         16 files,  866 lines
    │   ├── model/                       5   search_result, store99_*, menu_category
    │   ├── repository/                  6   abstract contracts
    │   └── service/                     5   deep_link, restaurant, search, store99, wallet
    ├── di/                             16 files,  349 lines  ← one provider file per concern
    ├── platform/                        6 files, 1,370 lines
    │   ├── location/location_service.dart   281  GPS + Google Geocoding REST via Dio
    │   ├── network/network_status_provider.dart 58  InternetAddress.lookup poll, 5 s
    │   ├── notifications/push_service.dart  457  ★ full FCM lifecycle
    │   ├── payment/payment_gateway.dart     272  Razorpay
    │   ├── realtime/socket_service.dart     174  order + chat events
    │   └── speech/speech_service.dart       128  voice search
    └── presentation/                  127 files, 43,084 lines  ← 83 % of the app
        ├── about, address, auth, branding, cart, chat, checkout, common,
        ├── common_widgets, coupons, favorites, home, main, navigation,
        ├── notifications, offers, orders, payment, profile, referral,
        └── restaurant, search, splash, wallet
```

### What food is good at

- **`core/network/api_client.dart` (354 lines).** Base URL + timeouts, bearer injection, `{success,message,data}` envelope unwrap, **single-flight 401 refresh with replay**, typed `Failure` mapping, express-validator field-error extraction, and a `SharedPreferences`-backed GET cache with a synchronous `peek()` for instant first paint plus offline fallback on error. This is the single best asset in either codebase and it becomes the merged app's network layer.
- **`platform/notifications/push_service.dart` (457 lines).** Handles all three delivery states (foreground via local notifications, background via `onMessageOpenedApp`, terminated via `getInitialMessage`), token refresh, register-on-login / unregister-on-logout including `deleteToken()` and `cancelAll()`, and routes deep links **outward through a callback** instead of touching navigation itself.
- **Riverpod 3 idiom throughout.** `Notifier` in 23 files, `AsyncNotifier` in 3, `NotifierProvider` in 26. No `StateNotifier` anywhere.
- **`di/` split per concern** (16 small files) rather than one god-file.

### Where food is weak

- **`presentation/` is 83 % of the codebase and the screens are enormous.** `cart_screen.dart` 2,629 lines. `profile_screen.dart` 1,974. `restaurant_screen.dart` 1,599. `add_address_screen.dart` 1,436. `order_tracking_screen.dart` 1,429. `store99_screen.dart` 1,357. `restaurant_card.dart` **1,220 lines for one card**. These are not going to be re-plumbed onto shared components cheaply.
- **`domain/` is vestigial.** 866 lines across 16 files, and only 6 of the 10 datasources have a repository, only 6 repositories have a domain contract. The layering is aspirational, not enforced — several viewmodels call datasources directly.
- **Connectivity is a 5-second `InternetAddress.lookup` poll.** Battery and wakeup cost for something `connectivity_plus` (already in taxi's pubspec) reports for free.
- **Duplicate leaf files:** `presentation/profile/viewmodels/referral_viewmodel.dart` is **1 line** and `presentation/referral/viewmodels/referral_viewmodel.dart` is 20 — an abandoned move.
- **`freezed` / `json_serializable` / `build_runner` declared, never used.** Zero generated files. All 16 models are hand-written `fromJson`.

---

## 1.3 Taxi app — structure

Feature-first, three-layer per feature:

```
lib/
├── main.dart                      86    Hive init → secure storage → Firebase (try/catch)
│                                        → ProviderScope overrides → _AppBootstrapper
├── app/
│   ├── app.dart                   38    TaxiUserApp: MaterialApp.router + NoDriverWatcher
│   └── router.dart               217    global `final appRouter`, 60 flat routes
├── core/                          29 files, 1,997 lines
│   ├── constants/                  3    api_constants 110, app_constants 84, storage_keys 14
│   ├── navigation/navigator_key.dart  3
│   ├── network/                    3    api_client 40, api_exception 44, dio_client 40
│   ├── providers/                  2    core_providers 51, theme_provider 41
│   ├── services/                   7    audio 42, location 137, notification 98,
│   │                                    razorpay 54, route_polyline 118,
│   │                                    socket_events 25, socket 125
│   ├── storage/                    2    local (Hive, 5 boxes) 19, secure 19
│   ├── theme/                      4    app_colors 69, app_map_style 157,
│   │                                    app_text_styles 63, app_theme 201
│   └── utils/                      7    formatters, marker_icon_loader, polyline_decoder,
│                                        route_marker_helper, snackbar_utils, validators,
│                                        vehicle_marker_icons
├── features/                     122 files, 19,316 lines
│   ├── home/          26 files 5,895   ← ride booking flow + service launcher
│   ├── ride/          15 files 4,223   ← tracking, chat, rating, history, detail
│   ├── delivery/      13 files 3,623   ← THIS IS THE PARCEL MODULE
│   ├── auth/          11 files 1,178
│   ├── profile/         9 files   854
│   ├── support/         8 files   793   ← tickets, safety centre, SOS
│   ├── rental/          7 files   767
│   ├── wallet/          5 files   336
│   ├── subscription/    4 files   328
│   ├── misc/            9 files   282   ← 8 system/error screens
│   ├── onboarding/      1 file    236
│   ├── notifications/   5 files   231
│   ├── settings/        4 files   272
│   ├── rewards/         1 file    168
│   ├── promo/           3 files    69
│   └── splash/          1 file     61
└── shared/widgets/                19 files, 1,429 lines
```

### What taxi is good at

- **The feature-first shape is the right one** for a super app. `features/<name>/{application,data,presentation}` maps almost 1:1 onto `modules/<name>/…` in the target tree. Food's `presentation/<feature>` + `data/models` split does not — food's models and datasources for one feature are scattered across three top-level folders.
- **`SocketService` handles reconnection correctly.** It replays every registered handler on reconnect and exposes `addConnectionListener` so ride rooms are re-joined after a network blip. The comment explaining why (Socket.IO rooms are per-connection; a reconnect gets a new socket id and the server drops room membership) is the kind of thing that only gets written after it broke in production. Food's socket re-joins tracking rooms too, but only for orders, and it does not expose the hook.
- **`features/misc/` — 8 dedicated system screens** (force update, maintenance, no internet, server error, GPS disabled, location denied, session expired, force logout). Food has none of these. Keep all of them; they become `shared/session/`.
- **`route_polyline_service`, `polyline_decoder`, `marker_icon_loader`, `vehicle_marker_icons`, `route_marker_helper`, `app_map_style`** — a genuinely reusable maps toolkit (~600 lines) that food's tracking map does not have.
- **`delivery/` is already a parcel product**, not a ride variant: its own categories, contacts sheet, address screen, vehicle picker, dispatch search, history.

### Where taxi is weak

- **`core/network` is three thin files that do almost nothing.** `ApiClient` (40 lines) returns `dynamic`, `DioClient` (40 lines) injects a bearer and fires `onUnauthorized` on 401 with **no refresh**. Every repository then hand-casts `Map<String,dynamic>.from(data['user'] ?? {})`.
- **Router is a 217-line global with 60 flat routes and no shell.** `AppBottomNavigationBar` is a plain widget each screen instantiates with a hardcoded `currentIndex`, calling `context.go()` — so every tab switch rebuilds the destination from scratch. No state preservation. Food's `StatefulShellRoute.indexedStack` is strictly better and the merged app needs that per module.
- **12 files on `StateNotifier`.** Blocking for the version merge.
- **Firebase init is wrapped in a swallow-everything `try/catch`** with a comment saying push just won't work if it fails. Fine for a standalone app that shipped without a Firebase project; unacceptable once ride dispatch depends on it.
- **`assets/` is 33 uncompressed PNGs at the folder root**, declared wholesale as `- assets/`. `markerbike.png` is 2.2 MB (a map marker). `Delivery.png` and `Ridenow.png` are 1.5 MB each. Two of the markers are already `.webp` (200 KB, 224 KB) which proves the conversion was started and abandoned.
- **9 declared-but-unimported packages** (§1.5).

---

## 1.4 Folder-by-folder comparison

| Concern | Food | Taxi | Verdict for merged app |
|---|---|---|---|
| App entry | `main.dart` 24 + `src/food_user_application.dart` 120 | `main.dart` 86 + `app/app.dart` 38 | New `main.dart` + `bootstrap.dart` + `app/super_app.dart`; take food's push wiring, taxi's `ProviderScope` overrides pattern |
| Routing | `presentation/navigation/` — `Provider<GoRouter>`, `StatefulShellRoute` | `app/router.dart` — global, flat | Food's provider + shell approach, extended per module |
| Env config | `core/constants/app_constants.dart` + `core/config/api_config.dart` — uses `String.fromEnvironment` | `core/constants/app_constants.dart` + `api_constants.dart` — **all hardcoded** | Food's dart-define approach, one `core/config/env.dart` |
| Network | `core/network/api_client.dart` 354 | `core/network/{api_client,dio_client,api_exception}` 124 | **Food wins outright**; make it multi-host |
| Errors | `core/error/failures.dart` — typed hierarchy | `core/network/api_exception.dart` — single class | Food's hierarchy + taxi's `fromDioError` mapping detail |
| Secure storage | `TokenStorage` — access+refresh, memory-cached, iOS `first_unlock` | `SecureStorageService` — single token, Android `encryptedSharedPreferences` | **Merge both**: food's shape + taxi's Android option (see [04 §5.6](04-dependency-merge.md)) |
| KV / local DB | `SharedPreferences` (5 files) | **Hive**, 5 boxes (recent searches, saved addresses, emergency contacts, favourite drivers, settings) | Keep both, behind `KvStore` and `BoxStore` facades. Hive is genuinely needed for the taxi boxes |
| Realtime | `platform/realtime/socket_service.dart` 174 — order + chat streams | `core/services/socket_service.dart` 125 + `socket_events.dart` 25 | Neither; both become `SocketChannel`s behind one gateway |
| Push | `platform/notifications/push_service.dart` 457 | `core/services/notification_service.dart` 98 | **Food wins**; taxi's ride-audio hook folds in as a module resolver side-effect |
| Location | `platform/location/location_service.dart` 281 — Google Geocoding **REST** via Dio, structured address fields | `core/services/location_service.dart` 137 — `geocoding` **plugin**, 50 m grid cache + 3 s throttle + <50 m skip | **Split**: food's structured `UserLocationResult` + REST geocoder, taxi's caching/throttling wrapper on top |
| Maps helpers | `core/utils/map_styles.dart` 26; `orders/widgets/live_tracking_map.dart` 894 | `core/theme/app_map_style.dart` 157 + 4 marker/polyline utils ~350 | **Taxi wins** on helpers; food's 894-line tracking map is a module screen, not shared |
| Payments | `platform/payment/payment_gateway.dart` 272 | `core/services/razorpay_service.dart` 54 | **Food wins**; note taxi also has PhonePe endpoints with no client code |
| Theme | `presentation/branding/` — 5 files, mutable `AppColors.primary`, Poppins via `google_fonts`, `ScreenUtilInit` | `core/theme/` — 4 files, `const AppColors`, Roboto, no screenutil | Neither; new `design_system/` with tokens + `ThemeExtension` (see [05 §6.11](05-shared-components.md)) |
| Shared widgets | `presentation/common_widgets/` 12 files ~1,300 lines | `shared/widgets/` 19 files 1,429 lines | Merge into `design_system/components/`; 6 direct duplicates (see [03 §4](03-file-migration-map.md)) |
| System/error screens | none | `features/misc/` 9 files | **Taxi wins**; becomes `shared/session/` |
| DI | `src/di/` 16 files, 349 lines | `core/providers/core_providers.dart` 51 + per-feature `*_providers.dart` | Food's granularity + taxi's boot-time `overrideWithValue` |

---

## 1.5 Dependency comparison (summary — full analysis in Chapter 5)

### Version conflicts requiring a migration, not a bump

| Package | Food | Taxi | Gap |
|---|---|---|---|
| `flutter_riverpod` | **3.3.2** | **2.6.1** | Major. `StateNotifier` in 12 taxi files |
| `go_router` | **17.3.0** | **14.6.2** | 3 majors |
| `firebase_core` | **4.12.1** | **3.8.0** | Major |
| `firebase_messaging` | **16.4.3** | **15.1.6** | Major |
| `flutter_local_notifications` | **22.2.0** | **18.0.1** | 4 majors; **confirmed API break** (positional → named) |
| `socket_io_client` | **3.1.6** | **2.0.3+1** | Major |
| `geolocator` | **14.0.3** | **13.0.2** | Major |
| `flutter_secure_storage` | **10.3.1** | **9.2.2** | Major |
| `permission_handler` | **12.0.3** | **11.3.1** | Major |
| `share_plus` | **13.3.0** | **10.1.2** | 3 majors |
| `google_fonts` | **8.2.0** | **6.2.1** | 2 majors |
| `intl` | **0.20.2** | **0.19.0** | Pinned by `flutter_localizations` |
| `razorpay_flutter` | **1.4.5** | **1.3.7** | Minor |
| Dart SDK | `^3.11.4` | `^3.12.2` | **Taxi requires the newer SDK** — merged floor is `^3.12.2` |

### Food-only

`flutter_screenutil` (32 files), `speech_to_text` (1), `video_player` (3), `webview_flutter` (1), `firebase_database` (1), `flutter_polyline_points` (2), `flutter_localizations`

### Taxi-only

`hive` + `hive_flutter` (2), `connectivity_plus` (1), `geocoding` (4), `shimmer` (1), `pin_code_fields` (1), `smooth_page_indicator` (1), `audioplayers` (1), `package_info_plus` (1)

### Dead in both (delete in Phase 1)

| App | Package | Files importing it |
|---|---|---|
| Food | `freezed_annotation` | 0 |
| Food | `json_annotation` | 0 |
| Food | `freezed` (dev) | 0 generated files |
| Food | `json_serializable` (dev) | 0 generated files |
| Food | `build_runner` (dev) | nothing to generate |
| Food | `flutter_launcher_icons` | 0 — and it is in `dependencies`, not `dev_dependencies`, with no config block |
| Taxi | `flutter_rating_bar` | 0 |
| Taxi | `logger` | 0 |
| Taxi | `device_info_plus` | 0 |
| Taxi | `lottie` | 0 |
| Taxi | `flutter_svg` | 0 |
| Taxi | `fl_chart` | 0 |
| Taxi | `equatable` | 0 |
| Taxi | `shared_preferences` | 0 direct (food uses it; keep at merged level) |
| Taxi | `path_provider` | 0 direct (transitive via `hive_flutter`; can drop the explicit entry) |

Deleting these before the merge removes 14 packages from the conflict surface at zero risk.

---

## 1.6 Architecture comparison

### Food: layered, weakly enforced

```
presentation/<feature>/{screens,widgets,viewmodels}
        ↓ (di/*_providers.dart)
domain/{repository,service,model}          ← only 6 of 10 datasources are covered
        ↓
data/{repository,datasources,models}
        ↓
core/{network,storage,config,error}
```

Strength: `core` is genuinely feature-agnostic and reusable as-is.
Weakness: a feature is spread across four top-level folders. Moving "cart" means touching `presentation/cart/`, `data/models/cart_item_model.dart`, `data/datasources/order_remote_datasource.dart`, `di/order_providers.dart`. That makes it very hard to lift a feature into a module.

### Taxi: feature-first, no platform layer worth the name

```
features/<feature>/presentation
        ↓
features/<feature>/application     ← controllers + state + providers
        ↓
features/<feature>/data            ← repository + models, co-located
        ↓
core/{network,services,storage,theme,utils}
```

Strength: a feature is one folder. `features/delivery/` is self-contained enough to become `modules/parcel/` almost mechanically.
Weakness: `core` is thin and `core/services/` is a grab bag (audio, location, notifications, razorpay, polyline, socket) with no separation between platform integration and business logic.

### Target: three tiers, explicit boundaries

```
modules/{food,taxi,parcel,rental}    ← may import shared/ , design_system/ , core/
                                       MUST NOT import another module
shared/{auth,profile,wallet,address,activity,search,…}
                                     ← may import design_system/ , core/
                                       MUST NOT import modules/
design_system/                       ← may import core/tokens only
core/                               ← imports nothing above it. Zero feature knowledge
```

That single import rule — enforced by a lint, not by good intentions — is what stops the super app from collapsing back into a ball of mud six months in. Details in [Chapter 2](02-target-architecture.md).

---

## 1.7 Reusable code inventory

Ranked by value ÷ effort. This is what makes the merge worth doing rather than rewriting.

| Rank | Asset | Owner | Lines | Reuse |
|---|---|---|---|---|
| 1 | `ApiClient` (refresh, envelope, typed failures, GET cache) | Food | 354 | Becomes `core/network/api_client.dart` verbatim + a `baseUrl` parameter |
| 2 | `PushService` (3 delivery states, token lifecycle) | Food | 457 | Becomes `core/push/push_service.dart`; deep-link resolution swapped for the module registry |
| 3 | Maps toolkit (polyline decode, route markers, vehicle icons, map style, icon loader) | Taxi | ~600 | Becomes `core/maps/*` unchanged; food's tracking map immediately benefits |
| 4 | `features/misc/` system + error screens | Taxi | 282 | Becomes `shared/session/presentation/*`; food has no equivalent |
| 5 | Socket reconnect + handler replay + `addConnectionListener` | Taxi | 125 | Becomes the reconnect strategy inside `SocketChannel` |
| 6 | `TokenStorage` (memory-cached secure pair) | Food | 64 | Becomes `core/storage/token_storage.dart` |
| 7 | `payment_gateway.dart` (Razorpay) | Food | 272 | Becomes `core/payment/`; taxi's PhonePe endpoints get a second adapter |
| 8 | `LocationService` structured address result | Food | 281 | Split into `core/location/{location_service,geocoding_service}` |
| 9 | Geocode grid cache + throttle + skip | Taxi | ~50 | Wraps #8 |
| 10 | `skeleton_loading.dart` (360) + `shimmer_widgets.dart` (80) | Both | 440 | One skeleton system in `design_system/components/skeletons/` |
| 11 | `failures.dart` typed hierarchy | Food | 46 | `core/error/failure.dart` |
| 12 | `AppModuleModel` + `all_services_screen` | Taxi | 367 | **The super-app hub already exists in embryo** — it reads `/users/app-modules` and routes by `transport_type`. This becomes the module launcher |
| 13 | `NoDriverWatcher` (app-wide event → route) | Taxi | 95 | Generalises into the module-level event watcher pattern |
| 14 | `exit_confirmation_dialog`, `offline_banner`, `top_toast`, `app_refresh_indicator`, `smart_image` | Food | ~500 | Straight into `design_system/components/` |

Note #12 specifically: taxi's `all_services_screen.dart` already fetches a server-driven module list and maps `transport_type`/`service_type` to routes, with a hardcoded fallback list. That is exactly the hub the super app needs, and it means the *server side* of module discovery partly exists too.

---

## 1.8 Duplicate logic to eliminate

Counted, with the winner named. Full file-level table in [Chapter 4](03-file-migration-map.md).

| Duplicated concern | Food | Taxi | Kept |
|---|---|---|---|
| HTTP client | `core/network/api_client.dart` 354 | `core/network/{api_client,dio_client}` 80 | Food |
| Error type | `failures.dart` 46 | `api_exception.dart` 44 | Food + taxi's Dio mapping |
| Auth repository | `data/repository/auth_repository_impl.dart` 123 + datasource 110 | `features/auth/data/auth_repository.dart` 99 | One `shared/auth` — **needs B1/B2** |
| `UserModel` | 133 lines (referral, wallet, verification, DOB, anniversary) | 69 lines (`currentRideId`, `profileImage`) | Merged core + module extensions |
| OTP screen | `auth/screens/otp_screen.dart` 428 | `auth/presentation/otp_screen.dart` 215 | Food's (richer); reuse taxi's `otp_field.dart` widget |
| Profile setup | 273 | 123 | Food's |
| Profile screen | 1,974 | 280 | **Rebuild** — see [05 §6.1](05-shared-components.md) |
| Edit profile | 1,099 | 176 | Food's, plus taxi's image upload path |
| Wallet screen | 926 | 128 + `topup_sheet` 113 | Food's UI + taxi's top-up sheet — **needs B6** |
| Notifications screen | 286 | 94 | Food's; taxi's settings screen kept separately |
| Splash | 247 | 61 | New shared splash (module-agnostic) |
| About screen | 880 | 85 | Food's, driven by CMS |
| Primary button | `primary_button.dart` 51 | `primary_button.dart` 94 + `secondary_button.dart` 44 | Taxi's (has variants) restyled to design-system tokens |
| Text field | `custom_text_field.dart` 58 | `app_text_field.dart` 61 | One `AppTextField` |
| Empty state | `empty_state_widget.dart` 58 | `empty_state.dart` 59 | One `EmptyState` |
| Loading / skeleton | `skeleton_loading.dart` 360 | `shimmer_widgets.dart` 80 + `loading_widget.dart` 34 | One skeleton system |
| Snackbar / toast | `app_snackbar.dart` 146 + `top_toast.dart` 221 | `snackbar_utils.dart` 48 | One feedback API |
| Bottom nav | `main/widgets/custom_bottom_nav.dart` 136 (shell-driven) | `shared/widgets/app_bottom_navigation_bar.dart` 121 (per-screen) | Food's shell-driven pattern |
| Location service | 281 | 137 | Split (see §1.7 #8/#9) |
| Socket | 174 | 125 | Neither — gateway |
| Push | 457 | 98 | Food |
| Razorpay | 272 | 54 | Food |
| Chat | `chat/` 570 + datasource 71 + model 121 (REST + socket) | `ride/presentation/ride_chat_screen.dart` 455 (socket only) | **Two implementations to reconcile** — needs B10 |
| Order/ride history | `orders/screens/orders_screen.dart` 973 | `ride_history_screen` 429 + `delivery_history_screen` 56 + `rental_history_screen` 181 | One Activity page — needs B7 |
| Address / places | `address/screens/add_address_screen.dart` 1,436 + `/food/user/addresses` | `saved_places_provider` 80 + `saved_places_screen` 147, **Hive-local** | One address book — needs B8 |
| Referral | `referral/` 7 files ~1,146 | `rewards_screen.dart` 168 + `/common/referrals/*` | Food's UI, one backend |
| Promo/coupon | `cart/widgets/coupon_sheet.dart` 332 + `coupons_viewmodel` 57 | `promo/` 69 + `promo_screen` 114 | One coupon engine — needs B9 |
| Support | `profile/screens/help_support_screen.dart` 840 + chat | `support/` 8 files 793 (tickets, SOS, safety) | Taxi's ticket model + food's UI — needs B10 |

**Rough duplicate-elimination estimate: ~6,000–7,000 lines removed**, mostly from the platform layer and shared widgets, before counting the shared-feature collapse in Phase 7 (which is larger but backend-gated).

---

## 1.9 What is *not* duplicated — the genuinely additive surface

Worth stating plainly, because it is the reason a merge beats a rewrite. These have no counterpart on the other side and move across essentially untouched:

**Food-only:** restaurant discovery (`restaurant_screen` 1,599, `restaurant_card` 1,220, `food_detail_screen` 1,083, `food_detail_sheet` 1,185, `variant_picker_sheet` 324), cart (`cart_screen` 2,629 + 5 widgets), Store99 (`store99_screen` 1,357 + service/repo/state), favourites (565 + vm), voice search (`voice_search_dialog` 308 + `speech_service` 128), order lifecycle screens (success 914, delivered 830, tracking 1,429, `live_tracking_map` 894, `rate_order_sheet` 343), zones, hero/promo banners, cashback + refunds ledger.

**Taxi-only:** ride booking funnel (`home_screen` 1,380, `search_destination_screen` 926, `ride_type_screen` 625, `confirm_booking_screen` 246, `finding_driver_screen` 397, `map_picker_screen` 254, `schedule_ride_sheet` 80), ride lifecycle (`ride_tracking_screen` 658, `ride_detail_screen` 596, `rating_review_screen` 757, `ride_completion_payment_sheet` 185), parcel (`delivery_address_screen` 1,165, `delivery_vehicle_screen` 732, `new_delivery_screen` 375, `finding_captain_screen` 285, `delivery_contacts_sheet` 278), rental (3 screens + repo + 2 models), SOS + safety centre + tickets, subscriptions, fare calculator, vehicle types / set-prices, `misc/` system screens, and **bus + pooling endpoints declared in `api_constants.dart` with no client code at all** (a fifth and sixth module the backend already anticipates).

---

## 1.10 Chapter 1 conclusions

1. **Food is the host.** 2.2× the code, newer everything, and the only decent platform layer.
2. **Taxi's folder shape is the host's target shape.** Migrate food's four-way feature split into taxi's feature-first layout, not the reverse.
3. **The version gap is the real project.** Riverpod 2→3 (12 files), go_router 14→17, Firebase 3→4, local-notifications 18→22 (confirmed API break). Do this in the taxi repo, standalone, before merging.
4. **Two Firebase projects and two identity systems are hard blockers** on the shared-feature collapse, not on the structural merge.
5. **Namespacing is mandatory.** 20 class collisions, 24 filename collisions, 6 provider collisions, 9 route collisions.
6. **~14 dependencies can be deleted before starting**, at zero risk.
7. **Localisation is a separate project** (74k lines of hardcoded strings), and must not gate the merge.
8. **The hub already half-exists** in taxi's `all_services_screen` + `/users/app-modules`.
