# Chapter 18 — Execution Runbook

Folder-by-folder migration checklist, organised into phases with explicit exit gates. Nothing here has been executed.

---

## 18.0 How to use this

Each phase has: **entry condition**, **work items**, **exit gate**. Do not start a phase until the previous gate passes — the gates exist because the failure mode of a merge like this is discovering at Phase 7 that Phase 4 was subtly wrong.

**Phases 0–6 need no backend changes.** Phase 7 is gated on the merged backend. Phases 8–9 follow.

```
Phase 0  Freeze & baseline           ─┐
Phase 1  Prune & assets              ─┤ can start today
Phase 2  Taxi forward-migration      ─┤ in the taxi repo, standalone
Phase 3  Skeleton & hub              ─┤
Phase 4  Platform unification        ─┤
Phase 5  Taxi module import          ─┤
Phase 6  Parcel & rental split       ─┘
Phase 7  Shared collapse             ← NEEDS MERGED BACKEND
Phase 8  Performance & size
Phase 9  Localisation                ← separate project
```

---

## Phase 0 — Freeze and baseline

**Entry:** none.

- [ ] `git init` the taxi repo if needed — **food has `.git`, taxi does not.** Nothing else in this runbook is safe without version control on both sides
- [ ] Tag both repos: `pre-superapp-merge`
- [ ] Record `flutter --version` and `dart --version`; pin one SDK for both repos
- [ ] Baseline **startup**: `flutter run --profile --trace-startup` for each app; save `build/start_up_info.json`
- [ ] Baseline **size**: `flutter build appbundle --release --analyze-size` for each app; save the JSON
- [ ] Baseline **APK**: `flutter build apk --release --split-per-abi --analyze-size` for each app — this is the number to compare against the brief's 40/45 MB
- [ ] Record the food app's release behaviour with `dart-define` overrides so staging config is known to work
- [ ] Write down the current happy paths as a manual regression script:
  - food: browse → restaurant → add to cart → checkout → track → delivered → rate
  - food: guest browse → login from cart → return to cart
  - taxi: home → destination → vehicle → confirm → searching → accepted → track → complete → rate
  - taxi: parcel → vehicle → addresses → contacts → dispatch
  - taxi: rental → vehicle → book
  - both: login, logout, push received in all three app states, wallet, notifications
- [ ] Confirm ownership of the 10 backend questions (B1–B10) with whoever owns the backend merge
- [ ] **Decide B3 (which Firebase project survives) now** — it has the longest lead time and it affects the driver app too

**Exit gate:** both apps build in release, both baselines recorded, regression script written, B3 decided.

---

## Phase 1 — Prune and assets

**Entry:** Phase 0 gate. Runs in both repos independently, in parallel with Phase 2.

### 1a. Dead dependencies

- [ ] **Food:** remove `freezed_annotation`, `json_annotation`, `flutter_launcher_icons` (from `dependencies`), and dev `freezed`, `json_serializable`, `build_runner`
- [ ] **Taxi:** remove `flutter_rating_bar`, `logger`, `device_info_plus`, `lottie`, `flutter_svg`, `fl_chart`, `equatable`, explicit `path_provider`, explicit `shared_preferences`
- [ ] `flutter pub get` + release build both apps to confirm nothing was transitively load-bearing

### 1b. Dead files

- [ ] Delete `F: src/presentation/profile/viewmodels/referral_viewmodel.dart` (1-line orphan)
- [ ] Delete `flutter_taxi_user/{linux,macos,windows}/`
- [ ] Delete `flutter_taxi_user/backend/taxi-new/{fix*.js, admins_diff.txt, *.log, scratch/, WhatsApp Image*.jpeg, driver_sample_upload.xlsx}`
- [ ] Delete the empty `Food_user/flutter-food-user-application/backend/food-backend/`
- [ ] Run `dart analyze` and clear every unused-import warning

### 1c. Asset pass — do this now, it is independent of everything

- [ ] Restructure both `assets/` trees into the target layout ([Ch. 17 §17.4](10-performance-and-app-size.md))
- [ ] Replace wholesale `- assets/` declarations with enumerated subdirectories
- [ ] Convert the 20 oversized taxi PNGs to WebP at rendered size (starting with `markerbike.png` 2.2 MB)
- [ ] Convert food's `images/` to WebP
- [ ] Move the 3.2 MB of bundled video to CDN streaming
- [ ] Convert the 3.3 MB of GIFs to animated WebP
- [ ] Deduplicate art by perceptual hash across both apps
- [ ] Re-run `--analyze-size`; confirm the asset bundle dropped from 29 MB toward ~4.4 MB

**Exit gate:** both apps build and pass the regression script; asset bundle measurably smaller; `dart analyze` clean.

---

## Phase 2 — Taxi forward-migration (in the taxi repo, standalone)

**Entry:** Phase 1a gate. **This is the phase people skip and regret.**

The taxi app must reach the merged app's package versions *while it is still a runnable, testable standalone app*. Debugging a Riverpod 3 migration and a tree merge simultaneously, inside something that does not compile, is how a two-week task becomes six.

Order matters — smallest blast radius first:

- [ ] Raise the SDK floor; confirm the pinned Flutter version
- [ ] `flutter_local_notifications` 18 → 22 (1 file). Positional → named args. **Keep the iOS `DarwinInitializationSettings`** — food lacks it
- [ ] `firebase_core` 3 → 4, `firebase_messaging` 15 → 16 (2 files). Check min platform versions
- [ ] `socket_io_client` 2 → 3 (1 file)
- [ ] `geolocator` 13 → 14, `permission_handler` 11 → 12 (2 files)
- [ ] `flutter_secure_storage` 9 → 10 (1 file). **Test the upgrade path from a v9-written token** — if it cannot be read, existing users are logged out on update, and that is a release-note item
- [ ] `share_plus` 10 → 13, `google_fonts` 6 → 8, `intl` 0.19 → 0.20 (6 files)
- [ ] `go_router` 14 → 17 (router + every nav call site)
- [ ] Add `riverpod_lint`
- [ ] `flutter_riverpod` 2 → 3 — the 6 genuine `StateNotifier` migrations:
  - [ ] `booking_controller` (239)
  - [ ] `ride_search_controller` (216) — move the debounce timer to `ref.onDispose`
  - [ ] `ride_tracking_controller` (263) — **joins a socket room in its constructor**; must become idempotent wiring with explicit teardown ([Ch. 8 §8.3](07-state-management-and-di.md))
  - [ ] `delivery_booking_controller` (260)
  - [ ] `emergency_contacts_provider` (38)
  - [ ] `subscription_providers` (16)
  - (the other 6 `StateNotifier`s are being replaced in Phase 7 — leave them on a compatibility shim or migrate mechanically, whichever is cheaper)
- [ ] Clear every `riverpod_lint` warning
- [ ] Full manual regression: ride, parcel, rental, auth, wallet, push in all three app states, **and a mid-ride network drop** (this is what the socket reconnect changes risk)

**Exit gate:** taxi runs standalone on the merged package set, full regression passes, network-drop-mid-ride verified.

---

## Phase 3 — Skeleton and hub (in the food repo)

**Entry:** Phase 1 gate. Food only; taxi is untouched.

- [ ] Rename the package `food_user_application` → `superapp_user`; update every import
- [ ] Create the target tree ([Ch. 2 §2.2](02-target-architecture.md)) as empty folders with `README.md` stubs stating each folder's dependency rule
- [ ] Add the three boundary greps to CI ([Ch. 2 §2.9](02-target-architecture.md)) — **before there is anything to violate them**
- [ ] Write `modules/app_module.dart` (the contract) and `modules/module_registry.dart`
- [ ] Write `core/config/env.dart` and `core/config/backend_endpoint.dart`; move every `String.fromEnvironment` into it
- [ ] Write `app/routes.dart` + per-module route-name constants — **names only, no behaviour**. Review this in isolation; it is the cheapest place to catch a bad route design
- [ ] Build `routerProvider` from the registry; move food's 32 routes under `/food/*`
- [ ] Add the 5+ legacy redirects (`/restaurant-detail/:id` → `/food/restaurants/:id`, etc.)
- [ ] Add `errorBuilder` → `NotFoundScreen` (food has none today)
- [ ] Write `shared/session/application/session_controller.dart` + `session_state.dart`
- [ ] Move taxi's 9 `misc/` screens into `shared/session/presentation/` (copy them across now — they are self-contained and food needs them)
- [ ] Implement the single `redirect` guard; **delete** the imperative navigation from `food_user_application.dart` and `splash_screen.dart`
- [ ] Write `bootstrap.dart` with the four tiers; move Firebase + background-handler registration out of `main.dart`
- [ ] Write `FoodModule implements AppModule` — routes only at this stage
- [ ] Build `app/hub/hub_screen.dart` from taxi's `all_services_screen.dart` (330 lines) + `app_module_model.dart`. Two tiles: Food (live), Taxi (disabled placeholder)
- [ ] Build `app/app_shell.dart`: offline banner + session watcher + active-job card host
- [ ] Introduce module `ProviderScope` for `/food/*`; move food's 17 controllers to module scope
- [ ] Rename food's 17 `*ViewModel` → `*Controller`

**Exit gate:** the food app runs as a super app with one module. Every food path is now `/food/*`, legacy links redirect, `/hub` works, back-from-module goes to `/hub`, DevTools shows food controllers **disposing** on module exit. Full food regression passes.

This gate is the most important one in the runbook. If food works cleanly as a one-module super app, the remaining phases are additive.

---

## Phase 4 — Platform unification

**Entry:** Phase 3 gate. Still food only.

### 4a. Network

- [ ] `F: src/core/network/api_client.dart` → `core/network/api_client.dart`; parameterise `baseUrl`, `tokenKey`, `supportsRefresh`, `cache`
- [ ] Extract `_CacheInterceptor` → `core/network/interceptors/cache_interceptor.dart` + `core/storage/cache_store.dart` (per-key Hive, not one `SharedPreferences` blob)
- [ ] `apiClientProvider` → `Provider.family<ApiClient, String>`
- [ ] `F: failures.dart` → `core/error/failure.dart`; add `core/error/error_mapper.dart`
- [ ] Apply the cache policy table ([Ch. 9 §9.6](08-api-socket-push.md))
- [ ] Update food's 10 datasources + 6 repositories to the keyed client

### 4b. Storage

- [ ] `token_storage.dart` → `core/storage/`; **add taxi's `AndroidOptions(encryptedSharedPreferences: true)`** alongside food's iOS accessibility option
- [ ] Write `core/storage/kv_store.dart`; replace all 5 direct `SharedPreferences` uses
- [ ] Write `core/storage/box_store.dart` (Hive, lazy per box)
- [ ] Add `clearAll()` used by logout — one auditable call

### 4c. Realtime

- [ ] Write `core/realtime/socket_channel.dart` merging both implementations ([Ch. 10 §10.3](08-api-socket-push.md))
- [ ] Write `socket_gateway.dart`, `socket_binding.dart`, `socket_lifecycle.dart`
- [ ] `FoodModule.socketBinding()` with food's 6 events + the `join-tracking` re-join
- [ ] Add background pause / foreground resume
- [ ] Add a per-channel connection-state stream; surface "reconnecting" in the UI

### 4d. Push

- [ ] `push_service.dart` → `core/push/`; strip `PushDeepLink`
- [ ] Write `push_message.dart`, `push_router.dart`, `push_channels.dart` (6 channels)
- [ ] `FoodModule.resolvePush()` carrying food's type→route mapping, **tolerating the legacy `link: '/food/user/orders/<id>'` payload**
- [ ] One background handler (food's, which re-inits Firebase in the isolate)
- [ ] `PushTokenSink` abstraction
- [ ] Generate `firebase_options.dart` with the FlutterFire CLI for the surviving project (B3)
- [ ] Merge the manifests: one Maps key via `manifestPlaceholders`, one default channel, food's permission superset, food's scheduled-notification receivers
- [ ] **Remove the hardcoded Maps keys from source** (2 manifests + 2 Dart files)

### 4e. Location, maps, payment, misc

- [ ] Split food's `location_service.dart` → `core/location/{location_service, geocoding_service, place_search_service}`
- [ ] Add taxi's `geocode_cache.dart` (grid + throttle + skip) on top; **drop the `geocoding` plugin**
- [ ] Move taxi's 5 map utils → `core/maps/{map_style, marker_factory, polyline_service}`; delete food's 26-line `map_styles.dart`
- [ ] Add bitmap caching with heading buckets to `MarkerFactory`
- [ ] Write `core/maps/map_camera.dart` + `live_track_controller.dart`; refactor food's `live_tracking_map.dart` (894) onto them
- [ ] `payment_gateway.dart` → `core/payment/` + `RazorpayAdapter` + `PaymentIntent`
- [ ] Write `core/connectivity/connectivity_service.dart`; **delete the 5 s DNS poll**
- [ ] Merge 3 audio players → `core/audio/audio_service.dart`
- [ ] `speech_service.dart` → `core/speech/`
- [ ] Write `core/permissions/permission_service.dart`; route all `permission_handler` calls through it

### 4f. Design system

- [ ] Create `design_system/tokens/{color_tokens, module_accent, spacing, radius, elevation, typography, motion}.dart`
- [ ] Write `app_theme_extension.dart` (`AppPalette`) + `context.palette`
- [ ] `app_theme.dart` → `buildLight(accent)` / `buildDark(accent)`, merging taxi's `dividerTheme`, `bottomSheetTheme`, `snackBarTheme`, `splashFactory`
- [ ] **Stage 1 of the colour migration only:** `AppColors` becomes a `@Deprecated` façade over the palette. Do **not** touch the 1,125 food call sites yet
- [ ] Merge the two theme-mode providers; **reconcile the persistence keys so nobody's dark mode resets**
- [ ] Write `ModuleTheme`; wrap `/food/*` in it
- [ ] Move food's 6 unique widgets + create the merged components ([Ch. 3 §3.3](03-file-migration-map.md))
- [ ] Write `design_system/components/map/app_map.dart` with correct Maps-ToS padding
- [ ] Copy taxi's 9 unique widgets across now (`otp_field`, `search_field`, `app_bar`, `bottom_sheet`, `section_title`, `profile_tile`, `price_card`, `map_fab`, `promo_banner`)

**Exit gate:** food runs on the unified platform layer. Push works in all three states. Socket reconnect verified with airplane-mode toggling. Tracking map still correct. No `SharedPreferences`, `Hive`, `FlutterSecureStorage`, or `permission_handler` import outside `core/`. Boundary greps pass. Startup trace **not worse** than the Phase 0 baseline.

---

## Phase 5 — Taxi module import

**Entry:** Phase 2 gate **and** Phase 4 gate. This is the merge proper.

- [ ] Copy `flutter_taxi_user/lib/` into the food repo as `lib/_taxi_staging/` (temporary, excluded from analysis)
- [ ] Split `T: core/constants/api_constants.dart` per [Ch. 3 §3.9](03-file-migration-map.md)
- [ ] Move `features/{home,ride}` → `modules/taxi/{api,data,application,presentation}`
  - [ ] rename `HomeScreen` → `TaxiHomeScreen`; `home_screen.dart` → `taxi_home_screen.dart`
  - [ ] strip the service-launcher grid out of taxi's home (it lives in `/hub` now)
  - [ ] `ride_search_controller` → `destination_search_controller`
- [ ] Rewrite taxi's 10 repositories against the unified `ApiClient` (~642 lines) — the largest mechanical task
- [ ] Write `TaxiModule implements AppModule`: routes, `socketBinding()`, `resolvePush()`, `providerOverrides()`, `warmUp()`
- [ ] Register `TaxiModule()`; enable its hub tile
- [ ] Namespace every taxi route to `/taxi/*`; add loader screens for the 3 unguarded `state.extra` casts
- [ ] Move taxi's 9 `misc/` screens out of staging (already copied in Phase 3 — delete the staging copies)
- [ ] Resolve the remaining name collisions: `AppConstants`, `AppColors`, `AppTextStyles`, `SocketService`, `LocationService`, `ApiClient`, `AboutScreen`, `SplashScreen`, `OtpScreen`, `ProfileSetupScreen`, `EditProfileScreen`, `NotificationsScreen`, `ProfileScreen`, `WalletScreen`, `UserModel`, `AuthRepository`, `AuthSession`, `PrimaryButton`, `WalletRepository`
- [ ] Drop `const` from taxi's 55 `const AppColors.*` expressions (compiler-guided)
- [ ] Point taxi's module at `BackendIds.taxi`; verify the dual-backend auth path (§9.3) end to end
- [ ] Two socket channels live simultaneously; verify both reconnect independently
- [ ] Move taxi's shared-ish screens to their `shared/` homes **as thin copies for now** — full collapse is Phase 7
- [ ] Delete `lib/_taxi_staging/`

**Exit gate:** both modules run in one binary. Full food **and** taxi regression passes. `/hub` switches modules; module accents apply; controllers dispose on exit. Both push types route correctly in all three app states. Both sockets reconnect after airplane-mode. Memory profile with **a live food order and a live ride simultaneously** is stable.

---

## Phase 6 — Parcel and rental split

**Entry:** Phase 5 gate. Mostly mechanical.

- [ ] `modules/taxi/…/delivery*` → `modules/parcel/`; rename `Delivery*` → `Parcel*` throughout
- [ ] `ParcelModule implements AppModule`; routes `/parcel/*`
- [ ] `modules/taxi/…/rental*` → `modules/rental/`
- [ ] `RentalModule implements AppModule`; routes `/rental/*`; loader screen for `/rental/vehicles/:id/book`
- [ ] Register both; add hub tiles
- [ ] Verify **no cross-module imports** (parcel and rental will want to reach into taxi — the greps will catch it)
- [ ] Delete the 3 module history screens (`delivery_history` 56, `rental_history` 181, and taxi's `ride_history` 429) — replaced in Phase 7. Until then, keep them reachable so nothing regresses
- [ ] Confirm `registry.enabled(flags)` correctly hides a disabled module and 404s its deep links

**Exit gate:** four modules registered. Parcel and rental flows pass regression. Boundary greps pass. Disabling a module via a flag removes its tile and its routes.

---

## Phase 7 — Shared collapse ← **NEEDS THE MERGED BACKEND**

**Entry:** Phase 6 gate **and** B1–B10 answered **and** the merged backend deployed to staging.

Order by risk, lowest first. Each item is independently shippable.

### 7a. Config (do this first — it proves the seam works)
- [ ] Point every module's `endpointId` at `'unified'`
- [ ] Verify the `Provider.family` collapses to one `ApiClient`, **with no module code changing**. If anything else needs editing, the Chapter 2 design was not followed and this is the moment to find out
- [ ] Collapse to one socket channel with namespaces (B5)
- [ ] One `PushTokenSink`

### 7b. Auth and profile (B1, B2)
- [ ] One `shared/auth`: food's screens + taxi's `exists`-branch flow + taxi's permission screens
- [ ] One `UserDto` (identity only); `currentRideId` → taxi state, `walletBalance` → wallet, referral fields → referral
- [ ] One token, one refresh path; delete the dual-token transitional code
- [ ] Rebuild `shared/profile/presentation/profile_screen.dart` as shell + `profileSections()` — **1,974 lines → ~250**
- [ ] Move `delete_account_screen` to shared (**Play Store requirement**)

### 7c. Session
- [ ] `SessionController` wired to the real force-update / maintenance / force-logout signals
- [ ] Delete every remaining imperative auth navigation

### 7d. Wallet (B6)
- [ ] One balance, read never computed; **integer paise, not `double`**
- [ ] Food's screen + taxi's top-up sheet
- [ ] Module-tagged transaction list with filter chips
- [ ] `WalletAdapter` as a payment adapter
- [ ] Balance chip in `/hub` + both checkouts

### 7e. Address (B8)
- [ ] One server-backed `AddressDto`; taxi's Hive box becomes a write-through cache
- [ ] **One-time migration of existing taxi users' Hive saved places to the server** — real user data
- [ ] One editor (food's) + one picker (taxi's map picker) + `id == null` for one-off destinations

### 7f. Activity (B7)
- [ ] `ActivitySource` per module; 4 history screens → 1 shell
- [ ] Cursor pagination against `GET /activity`, or the documented approximate K-way merge if B7 is declined
- [ ] `ActiveJobsController` at app scope; 0/1/2/3+ card rendering in `app_shell`
- [ ] Reorder, rebook, rate, invoice, help wired through `handleAction`

### 7g. Notifications (B4)
- [ ] One inbox with a module filter
- [ ] Per-module × per-category settings matrix
- [ ] Verify all 6 channels; verify the backend sets `android_channel_id` per message

### 7h. Support (B10)
- [ ] Reconcile the two chat implementations onto food's REST+socket model with a `ChatContext` discriminator — **this fixes taxi's lost-on-reconnect ride chat**
- [ ] Taxi's tickets + safety centre into shared
- [ ] SOS app-wide with an optional `JobRef`

### 7i. Offers, referral, search, settings (B9)
- [ ] `CouponDto.applicableTo` cross-module; one coupon sheet driven by `PaymentIntent`
- [ ] Food's referral UI shared; one code per user
- [ ] `SearchSource` contributions; food's search screen → shell + tiles; **taxi's destination picker stays separate**
- [ ] One recents store, module-tagged
- [ ] Settings hub (taxi's) + food's About; **1,313 lines of legal text → CMS**

**Exit gate:** one user, one token, one wallet balance, one activity feed, one address book, one chat, one profile screen. Full regression across all four modules plus every shared surface. Taxi Hive-address migration verified on a device that has the old app's data.

---

## Phase 8 — Performance and size

**Entry:** Phase 7 gate.

- [ ] Verify the four bootstrap tiers; confirm 4 of 5 Hive boxes are Tier 3
- [ ] Notification permission off first frame
- [ ] `--trace-startup` vs. the Phase 0 baselines
- [ ] `--analyze-size` vs. the Phase 0 baselines, per module
- [ ] **Impeller decision re-tested**: video × 3 devices, map scroll/zoom × 3 devices, both states
- [ ] Colour-migration Stages 2–3: `context.palette` in `design_system/` and `shared/`, then taxi/parcel/rental (205 sites), then food (1,125 sites). Delete `AppColors` when the deprecation count hits zero
- [ ] `memCacheWidth/Height` everywhere; `imageCache.maximumSizeBytes` set
- [ ] `RepaintBoundary` on map overlays and floating cards
- [ ] `ref.watch(p.select(...))` on the hot paths (start with the shell's cart watch)
- [ ] Release keystore; **remove debug signing**
- [ ] `--obfuscate --split-debug-info`; verify crash symbolisation still works
- [ ] R8 keeps for Razorpay and any reflective SDK
- [ ] Worst-case memory profile: live order + live ride + map + 20 min of browsing

**Exit gate:** startup not worse than the slower baseline; download size at or below the smaller baseline; release-signed AAB; no memory growth over a 20-minute session.

---

## Phase 9 — Localisation (separate project)

**Entry:** Phase 8 gate. Do not let this block anything.

- [ ] Register `localizationsDelegates` + `supportedLocales` in `super_app.dart` — **verify food's existing 3 localised strings actually resolve today; they may not**
- [ ] Wire `localeController` to `MaterialApp.locale`
- [ ] **Reduce the language list to what is actually translated** — shipping a Hindi option with no Hindi strings is worse than shipping English only
- [ ] Extract strings folder by folder: `design_system` → `shared` → `modules/taxi|parcel|rental` → `modules/food`
- [ ] CI check for new hardcoded user-facing strings in `shared/` and `design_system/`
- [ ] Re-expand the language list as ARB files land

Sizing: ~74,000 lines to audit, realistically 3,000–5,000 distinct strings. Months, not weeks.

---

## 18.1 Folder-by-folder quick reference

```
FOOD  Food_user/flutter-food-user-application/lib/
  main.dart                       → main.dart + bootstrap.dart              P3
  src/food_user_application.dart  → app/super_app.dart                      P3
  src/core/config/                → core/config/ + modules/food/api/        P4
  src/core/constants/             → core/config/env.dart + design_system/   P4
  src/core/error/                 → core/error/                             P4
  src/core/network/               → core/network/                           P4
  src/core/storage/               → core/storage/                           P4
  src/core/utils/                 → core/utils/ + core/audio/ + core/maps/  P4
  src/data/datasources/           → modules/food/api/ + shared/*/data/      P5,P7
  src/data/models/                → modules/food/data/models/ + shared/     P5,P7
  src/data/repository/            → modules/food/data/repositories/         P5
  src/di/                         → colocated *_providers.dart              P3,P4
  src/domain/model/               → modules/food/data/models/               P5
  src/domain/repository/          → DELETE (fold into impls)                P5
  src/domain/service/             → modules/food/data/repositories/         P5
  src/platform/location/          → core/location/                          P4
  src/platform/network/           → core/connectivity/                      P4
  src/platform/notifications/     → core/push/                              P4
  src/platform/payment/           → core/payment/                           P4
  src/platform/realtime/          → core/realtime/                          P4
  src/platform/speech/            → core/speech/                            P4
  src/presentation/branding/      → design_system/                          P4
  src/presentation/common_widgets/→ design_system/components/               P4
  src/presentation/navigation/    → app/ + modules/food/food_routes.dart    P3
  src/presentation/main/          → app/app_shell.dart + food shell         P3
  src/presentation/{home,restaurant,cart,checkout,orders,favorites,
                    offers,coupons}/  → modules/food/presentation/          P5
  src/presentation/{auth,profile,wallet,address,notifications,
                    referral,chat,about,search,splash}/ → shared/*/         P7
  src/presentation/common/webview_screen.dart → design_system/components/   P4

TAXI  flutter_taxi_user/lib/
  main.dart                       → bootstrap.dart (merged)                 P5
  app/app.dart                    → app/super_app.dart (merged)             P5
  app/router.dart                 → SPLIT: modules/*/​*_routes.dart          P5,P6
  core/constants/api_constants    → SPLIT ×4 (see Ch. 3 §3.9)               P5
  core/constants/app_constants    → core/config/env + design_system/tokens  P5
  core/navigation/                → app/di/app_providers.dart               P3
  core/network/                   → DELETE (food's client wins)             P5
  core/providers/                 → colocated + design_system/theme/        P4,P5
  core/services/audio             → core/audio/                             P4
  core/services/location          → core/location/geocode_cache.dart        P4
  core/services/notification      → DELETE                                  P4
  core/services/razorpay          → DELETE                                  P4
  core/services/route_polyline    → core/maps/polyline_service.dart         P4
  core/services/socket*           → core/realtime/                          P4
  core/storage/                   → core/storage/                           P4
  core/theme/                     → design_system/                          P4
  core/theme/app_map_style        → core/maps/map_style.dart                P4
  core/utils/{marker*,polyline*,route_marker*} → core/maps/                 P4
  core/utils/{formatters,validators}           → core/utils/                P4
  core/utils/snackbar_utils       → design_system/components/feedback/      P4
  features/auth/                  → shared/auth/                            P7
  features/delivery/              → modules/parcel/                         P6
  features/home/ (booking)        → modules/taxi/                           P5
  features/home/all_services      → app/hub/                                P3
  features/home/{saved_places,map_picker} → shared/address/                 P7
  features/home/recent_searches   → shared/search/                          P7
  features/misc/                  → shared/session/presentation/            P3
  features/notifications/         → shared/notifications/                   P7
  features/onboarding/            → shared/session/presentation/            P3
  features/profile/               → shared/profile/ + shared/settings/
                                     + modules/taxi (emergency contacts)    P7
  features/promo/                 → shared/offers/                          P7
  features/rental/                → modules/rental/                         P6
  features/rewards/               → shared/referral/                        P7
  features/ride/                  → modules/taxi/ + shared/{support,
                                     payment,activity}/                     P5,P7
  features/settings/              → shared/settings/                        P7
  features/splash/                → shared/session/presentation/            P3
  features/subscription/          → shared/subscription/                    P7
  features/support/               → shared/support/                         P7
  features/wallet/                → shared/wallet/                          P7
  shared/widgets/                 → design_system/components/ (16)
                                     + modules/taxi (2) + shared/activity (1) P4,P5
```

---

## 18.2 Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Riverpod 2→3 side-effect bugs in `ride_tracking_controller` | High | High | Phase 2 standalone; `riverpod_lint`; mid-ride network-drop test in the gate |
| Firebase project decision blocks Phase 4 | Medium | High | Decide B3 in Phase 0 — longest lead time, and it affects the driver app |
| Backend merge slips, stranding Phase 7 | Medium | Medium | Phases 0–6 deliver a working two-module super app on two backends. Ship it |
| `flutter_secure_storage` 9→10 logs out existing users | Medium | High | Explicit upgrade-path test in the Phase 2 gate; release note if unavoidable |
| Wallet double-counting ships | Low | **Severe** | The never-sum rule ([Ch. 14 §14.1](09-maps-search-wallet-activity.md)); Phase 7d gate |
| Impeller regression on taxi maps | Medium | Medium | Explicit 3-device × 2-state test in Phase 8 |
| Taxi users lose their Hive saved places | Medium | Medium | One-time migration in Phase 7e, verified on a device with old-app data |
| Memory growth from four resident modules | Medium | Medium | Module `ProviderScope` in Phase 3; worst-case profile in the Phase 5 and 8 gates |
| Cross-module imports creep in | High | Medium | CI greps from Phase 3, before there is anything to violate them |
| Colour migration attempted during the merge | Medium | High | Stage 1 only in Phase 4; Stages 2–4 in Phase 8 |
| iOS turns out to be unbuildable | Medium | High | Taxi has **no `Podfile`** and neither app has iOS Firebase config. Scope iOS separately before promising it |
| Debug signing reaches a store submission | Low | High | Phase 8 gate |
| 1,000-line screen refactors mixed into the merge | Medium | Medium | Explicitly deferred past Phase 8 |

---

## 18.3 What can start today

Without a single backend answer, and without touching the other repo:

| Work | Phase | Where |
|---|---|---|
| Delete 14 dead dependencies | 1a | both repos |
| Asset pass — 29 MB → ~4.4 MB | 1c | both repos |
| Baselines (startup, size) | 0 | both repos |
| Taxi forward-migration to the merged package set | 2 | taxi repo |
| Route-tree design as constants | 3 | food repo |
| `AppModule` contract + registry | 3 | food repo |
| Boundary greps in CI | 3 | food repo |
| Food namespaced to `/food/*` + legacy redirects | 3 | food repo |
| `/hub` from taxi's `all_services_screen` | 3 | food repo |
| `SessionController` + taxi's 9 system screens | 3 | food repo |
| Tiered `bootstrap()` | 3 | food repo |
| Module `ProviderScope` for food | 3 | food repo |
| Unified `core/` platform layer | 4 | food repo |
| `design_system/` + colour Stage 1 | 4 | food repo |
| Legal text → CMS | 4 | food repo |
| Release keystore | 0/8 | both repos |
| iOS scoping spike (`Podfile`, Firebase config) | — | both repos |

That is Phases 0–4 in full, plus the entirety of the taxi version migration — realistically the majority of the engineering effort, all available before the merged backend exists.

The parts that genuinely require the backend are the shared-feature collapse (Phase 7) and the config flip in 7a. Everything else is ours.
