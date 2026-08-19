# Chapter 5 — Dependency Merge

The `pubspec.yaml` reconciliation, and the migration work each version conflict implies.

---

## 5.1 Side-by-side

### Food — `food_user_application`

```yaml
environment: { sdk: ^3.11.4 }

dependencies:
  flutter, flutter_localizations
  cupertino_icons: ^1.0.8
  flutter_launcher_icons: ^0.14.4      # ← in the wrong section, unused
  flutter_riverpod: ^3.3.2
  go_router: ^17.3.0
  freezed_annotation: ^3.1.0           # ← unused
  json_annotation: ^4.12.0             # ← unused
  uuid: ^4.6.0
  google_fonts: ^8.2.0
  video_player: ^2.11.1
  shared_preferences: ^2.5.5
  cached_network_image: ^3.4.1
  flutter_screenutil: ^5.9.3
  speech_to_text: ^7.4.0
  permission_handler: ^12.0.3
  dio: ^5.10.0
  flutter_secure_storage: ^10.3.1
  geolocator: ^14.0.3
  razorpay_flutter: ^1.4.5
  socket_io_client: ^3.1.6
  share_plus: ^13.3.0
  url_launcher: ^6.3.2
  firebase_core: ^4.12.1
  firebase_database: ^12.4.6
  flutter_polyline_points: ^3.1.0
  firebase_messaging: ^16.4.3
  google_maps_flutter: ^2.18.0
  flutter_local_notifications: ^22.2.0
  webview_flutter: ^4.10.0
  image_picker: ^1.2.3
  intl: ^0.20.2

dev_dependencies:
  flutter_test, flutter_lints: ^6.0.0
  build_runner: ^2.15.1                # ← unused
  freezed: ^3.2.5                      # ← unused
  json_serializable: ^6.14.0           # ← unused
```

### Taxi — `taxiuser`

```yaml
environment: { sdk: ^3.12.2 }          # ← HIGHER than food

dependencies:
  flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1             # ← MAJOR conflict
  go_router: ^14.6.2                   # ← MAJOR conflict
  dio: ^5.7.0
  connectivity_plus: ^6.1.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.2.2       # ← MAJOR conflict
  path_provider: ^2.1.5                # ← unused directly
  shared_preferences: ^2.3.3           # ← unused directly
  google_maps_flutter: ^2.9.0
  geolocator: ^13.0.2                  # ← MAJOR conflict
  geocoding: ^3.0.0
  firebase_core: ^3.8.0                # ← MAJOR conflict
  firebase_messaging: ^15.1.6          # ← MAJOR conflict
  flutter_local_notifications: ^18.0.1 # ← MAJOR conflict, confirmed API break
  socket_io_client: ^2.0.3+1           # ← MAJOR conflict
  razorpay_flutter: ^1.3.7
  google_fonts: ^6.2.1                 # ← MAJOR conflict
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0
  flutter_rating_bar: ^4.0.1           # ← unused
  pin_code_fields: ^8.0.1
  lottie: ^3.2.0                       # ← unused
  flutter_svg: ^2.0.16                 # ← unused
  smooth_page_indicator: ^1.2.0
  fl_chart: ^0.69.2                    # ← unused
  audioplayers: ^6.1.0
  intl: ^0.19.0                        # ← conflict
  url_launcher: ^6.3.1
  permission_handler: ^11.3.1          # ← MAJOR conflict
  image_picker: ^1.1.2
  share_plus: ^10.1.2                  # ← MAJOR conflict
  uuid: ^4.5.1
  equatable: ^2.0.7                    # ← unused
  logger: ^2.5.0                       # ← unused
  package_info_plus: ^8.1.2
  device_info_plus: ^11.2.0            # ← unused

dev_dependencies:
  flutter_test, flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.1      # ← correctly placed, and configured
```

---

## 5.2 Classification

### Group A — identical or trivially compatible (11)

`flutter`, `cupertino_icons`, `dio` (5.10 vs 5.7 — same major), `cached_network_image` (identical), `url_launcher` (6.3.2 vs 6.3.1), `image_picker` (1.2.3 vs 1.1.2), `uuid` (4.6 vs 4.5), `google_maps_flutter` (2.18 vs 2.9 — same major), `razorpay_flutter` (1.4.5 vs 1.3.7), `flutter_lints` (identical `^6.0.0`), `flutter_test`.

Take the higher pin. No code changes. **`google_maps_flutter` 2.9 → 2.18 deserves a smoke test** on taxi's 12 map files even inside one major — nine minor versions is a lot of surface.

### Group B — major version conflicts requiring migration (12)

| Package | Food | Taxi | Merged | Taxi files affected | Cost |
|---|---|---|---|---|---|
| `flutter_riverpod` | 3.3.2 | 2.6.1 | **3.3.2** | 12 (`StateNotifier`) + all 60 provider declarations | **High** |
| `go_router` | 17.3.0 | 14.6.2 | **17.3.0** | `app/router.dart` + every `context.go/push` site | **High** |
| `flutter_local_notifications` | 22.2.0 | 18.0.1 | **22.2.0** | 1 (`notification_service.dart`) — being deleted anyway | Low |
| `firebase_core` | 4.12.1 | 3.8.0 | **4.12.1** | 2 | Low–Med **[VERIFY]** |
| `firebase_messaging` | 16.4.3 | 15.1.6 | **16.4.3** | 2 | Low–Med **[VERIFY]** |
| `socket_io_client` | 3.1.6 | 2.0.3+1 | **3.1.6** | 1 (`socket_service.dart`) — being rebuilt | Low **[VERIFY]** |
| `geolocator` | 14.0.3 | 13.0.2 | **14.0.3** | 1 | Low **[VERIFY]** |
| `flutter_secure_storage` | 10.3.1 | 9.2.2 | **10.3.1** | 1 | Low–Med — see §5.6 |
| `permission_handler` | 12.0.3 | 11.3.1 | **12.0.3** | 2 | Low **[VERIFY]** |
| `share_plus` | 13.3.0 | 10.1.2 | **13.3.0** | 3 | Med — 3 majors; the `share()` → `SharePlus.instance.share(ShareParams(…))` shape changed **[VERIFY]** |
| `google_fonts` | 8.2.0 | 6.2.1 | **8.2.0** | 1 | Low |
| `intl` | 0.20.2 | 0.19.0 | **0.20.2** | 2 | Low — but pinned by `flutter_localizations`; must match the SDK's constraint |

### Group C — food-only, keep (7)

| Package | Files | Keep because |
|---|---|---|
| `flutter_localizations` | — | Required for any localisation; taxi has none |
| `flutter_screenutil` | **32** | Deeply embedded in food's layout. See §5.4 — this is the one to think hard about |
| `speech_to_text` | 1 | Voice search; feeds unified search |
| `video_player` | 3 | And it is the reason Impeller is disabled ([Ch. 16](10-performance-and-app-size.md)) |
| `webview_flutter` | 1 | CMS pages, payment fallbacks |
| `firebase_database` | 1 | RTDB live order tracking — **coupled to Firebase project choice (B3)** |
| `flutter_polyline_points` | 2 | Overlaps taxi's hand-rolled decoder; see §5.5 |

### Group D — taxi-only, keep (8)

| Package | Files | Keep because |
|---|---|---|
| `hive` + `hive_flutter` | 2 | 5 boxes of genuinely local data (recent searches, saved places, emergency contacts, favourite drivers, settings). Rewriting on `SharedPreferences` would be a downgrade |
| `connectivity_plus` | 1 | **Also replaces food's 5-second `InternetAddress.lookup` poll.** Net win |
| `geocoding` | 4 | Platform reverse-geocoding. But see §5.5 — may be droppable |
| `shimmer` | 1 | Only if food's `skeleton_loading.dart` doesn't already cover it — it does. Candidate for removal |
| `pin_code_fields` | 1 | Taxi's `otp_field.dart`, which is the OTP widget we're keeping |
| `smooth_page_indicator` | 1 | Onboarding carousel, which we're keeping |
| `audioplayers` | 1 | Ride-start / ride-end cues. **Note food's audio players use a different mechanism** — check which package food's `referral_audio_player` uses and standardise |
| `package_info_plus` | 1 | Version display + force-update comparison |

### Group E — delete (14)

| Package | App | Import count |
|---|---|---|
| `freezed_annotation` | Food | 0 |
| `json_annotation` | Food | 0 |
| `freezed` (dev) | Food | 0 generated files |
| `json_serializable` (dev) | Food | 0 generated files |
| `build_runner` (dev) | Food | nothing to generate |
| `flutter_launcher_icons` (in `dependencies`) | Food | 0 — taxi's dev-dependency entry, with its config block, survives |
| `flutter_rating_bar` | Taxi | 0 |
| `logger` | Taxi | 0 |
| `device_info_plus` | Taxi | 0 |
| `lottie` | Taxi | 0 |
| `flutter_svg` | Taxi | 0 |
| `fl_chart` | Taxi | 0 |
| `equatable` | Taxi | 0 |
| `path_provider` (explicit) | Taxi | 0 direct — transitive via `hive_flutter` |

Plus two conditional removals: `shimmer` (superseded by food's skeleton system) and `shared_preferences` from taxi's list (food owns it).

**Do this first, in both repos, as its own commit.** It is zero-risk, and it removes 14 packages from the resolution graph before you start fighting real conflicts.

---

## 5.3 Proposed merged `pubspec.yaml`

```yaml
name: superapp_user
description: "Suvio Super App — food, rides, parcel, rental."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.2                # taxi's floor is higher; it wins

dependencies:
  flutter:            { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  cupertino_icons: ^1.0.8

  # ── State & navigation ─────────────────────────────
  flutter_riverpod: ^3.3.2
  go_router: ^17.3.0

  # ── Networking ─────────────────────────────────────
  dio: ^5.10.0
  connectivity_plus: ^6.1.0
  socket_io_client: ^3.1.6

  # ── Storage ────────────────────────────────────────
  shared_preferences: ^2.5.5
  flutter_secure_storage: ^10.3.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # ── Firebase ───────────────────────────────────────
  firebase_core: ^4.12.1
  firebase_messaging: ^16.4.3
  firebase_database: ^12.4.6          # RTDB order tracking — see B3
  flutter_local_notifications: ^22.2.0

  # ── Location & maps ────────────────────────────────
  google_maps_flutter: ^2.18.0
  geolocator: ^14.0.3
  geocoding: ^3.0.0                   # candidate for removal — §5.5
  flutter_polyline_points: ^3.1.0     # candidate for removal — §5.5

  # ── Payments ───────────────────────────────────────
  razorpay_flutter: ^1.4.5

  # ── UI ─────────────────────────────────────────────
  google_fonts: ^8.2.0
  flutter_screenutil: ^5.9.3          # decision: keep — §5.4
  cached_network_image: ^3.4.1
  smooth_page_indicator: ^1.2.0
  pin_code_fields: ^8.0.1

  # ── Media & device ─────────────────────────────────
  image_picker: ^1.2.3
  video_player: ^2.11.1
  webview_flutter: ^4.10.0
  audioplayers: ^6.1.0
  speech_to_text: ^7.4.0

  # ── Platform ───────────────────────────────────────
  permission_handler: ^12.0.3
  package_info_plus: ^8.1.2
  url_launcher: ^6.3.2
  share_plus: ^13.3.0
  intl: ^0.20.2
  uuid: ^4.6.0

dev_dependencies:
  flutter_test:      { sdk: flutter }
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
  custom_lint: ^0.7.0                 # for the boundary rules — Ch. 2 §2.9
  riverpod_lint: ^3.0.0               # catches Riverpod 3 misuse during migration

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/brand/app_icon.png"
  min_sdk_android: 21

flutter:
  generate: true
  uses-material-design: true
  assets:
    # NEVER `- assets/` wholesale. See Ch. 17 — taxi currently ships
    # 17 MB because of exactly that.
    - assets/brand/
    - assets/images/food/
    - assets/images/taxi/
    - assets/images/parcel/
    - assets/images/shared/
    - assets/markers/
    - assets/audio/
    - assets/gif/
    - assets/videos/
  fonts:
    - family: ManropeVariable
      fonts:
        - asset: assets/fonts/Manrope-VariableFont_wght.ttf
```

**Package count: 32 runtime + 5 dev**, down from 34 + 4 (food) and 37 + 3 (taxi) — 71 declarations collapsing to 37, with four modules instead of two apps.

---

## 5.4 The `flutter_screenutil` decision

`flutter_screenutil` appears in **32 of food's 212 files** and **0 of taxi's**. Options:

| Option | Cost | Verdict |
|---|---|---|
| **Keep it.** `ScreenUtilInit` stays at the app root; taxi/parcel/rental screens simply never call `.w`/`.h`/`.sp` | Near zero | ✅ **Recommended** |
| Remove it from food | 32 files, hundreds of call sites, and a full visual re-QA of the food module | High, no benefit |
| Adopt it in taxi | 100+ files touched for aesthetic consistency | High, no benefit |

Two operational rules if you keep it:

1. **Exactly one `ScreenUtilInit`, at the root.** Nesting a second one (e.g. per module) produces wrong scale factors silently.
2. **Do not let it leak into `design_system/`.** A shared button sized in `.h` units forces every consumer into screenutil's coordinate space. Design-system components use `spacing.dart` tokens in logical pixels; only food's own screens use `.w`/`.h`.

Long term, the design-system token scale should replace it. That is a post-merge cleanup, not a merge blocker.

---

## 5.5 Overlapping packages worth collapsing

### Geocoding: `geocoding` plugin vs. Google Geocoding REST

- Food: `location_service.dart` calls the Google Geocoding **REST API** via Dio, using `AppConstants.mapKey`, and parses structured fields (building, street, area, city, state, pincode).
- Taxi: `geocoding` **plugin** (`placemarkFromCoordinates`), taking whatever the platform's geocoder returns.

Two problems with keeping both: the same coordinate can produce two different address strings in two modules, and the plugin's output is platform-dependent (Android and iOS geocoders genuinely disagree).

**Recommendation:** keep food's REST path as the single geocoder, wrapped in taxi's grid-cache/throttle layer, and **drop `geocoding`**. This also removes a native dependency. Caveat: REST geocoding is a billed API call — the cache layer is what makes this affordable, which is exactly why taxi's caching code is worth salvaging.

### Polylines: `flutter_polyline_points` vs. `polyline_decoder.dart`

- Food uses `flutter_polyline_points` in 2 files (which itself calls the Directions API).
- Taxi has a 52-line hand-rolled decoder plus a 118-line `route_polyline_service`.

If the **backend** returns encoded polylines (food's RTDB node carries a `polyline` field — confirmed in `active_order_rtdb_model`), the client never needs the Directions API and taxi's decoder is sufficient and free.

**Recommendation:** default to taxi's decoder. Keep `flutter_polyline_points` only if some flow genuinely needs a client-side Directions call, and if so isolate it to one file in `core/maps/`.

### Skeletons: `shimmer` vs. `skeleton_loading.dart`

Food's 360-line skeleton system covers taxi's 80-line `shimmer_widgets`. **Drop `shimmer`.**

### Audio: `audioplayers` vs. food's players

Food's two audio players (137 lines total) need checking for which package they use. If they use `audioplayers`, it is already common. If they use something bundled or platform channels, standardise on `audioplayers` — it is the more capable option and taxi already ships it.

---

## 5.6 Migration notes per conflict

These are the specific things to look for. Items marked **[VERIFY]** need a changelog check when you pin the version; items without are confirmed from the source in this repo.

### `flutter_riverpod` 2.6.1 → 3.3.2 — the big one

**Confirmed from source:** taxi uses `StateNotifier` in 12 files and `StateNotifierProvider` in 11. Food uses `Notifier` (23 files), `AsyncNotifier` (3), `NotifierProvider` (26), and no `StateNotifier` at all.

Per-file rewrite pattern:

```dart
// before (taxi)
class LocaleNotifier extends StateNotifier<String> {
  final Ref ref;
  LocaleNotifier(this.ref) : super('en') {
    state = ref.read(localStorageServiceProvider).settings.get(key) ?? 'en';
  }
  void setLocale(String c) { state = c; /* persist */ }
}
final localeProvider = StateNotifierProvider<LocaleNotifier, String>((r) => LocaleNotifier(r));

// after (Riverpod 3 idiom, as food already writes it)
class LocaleController extends Notifier<String> {
  @override
  String build() => ref.read(kvStoreProvider).localeCode() ?? 'en';
  void setLocale(String c) { state = c; /* persist */ }
}
final localeProvider = NotifierProvider<LocaleController, String>(LocaleController.new);
```

The mechanical parts: constructor-body init moves into `build()`; `ref` comes from the base class instead of being injected; the provider factory takes `.new` instead of a closure.

The non-mechanical part: **`build()` is called on every dependency invalidation**, whereas a `StateNotifier` constructor ran once. Any controller that treated its constructor as "run this side effect once" — and taxi's do, e.g. `LocaleNotifier` reading Hive, `RideTrackingController` joining a socket room — needs its side effect moved to an explicit method or guarded. This is where subtle bugs will hide. Budget real time for the 12 files, not a find-and-replace.

**[VERIFY]** whether Riverpod 3 keeps a legacy `StateNotifier` shim. Even if it does, do not use it — you will be migrating twice.

Add `riverpod_lint` during this phase; it flags the common mistakes automatically.

### `go_router` 14.6.2 → 17.3.0

Taxi's router is a 217-line global with 60 flat routes; it is being rewritten into per-module route lists anyway ([Ch. 7](06-routing-and-navigation.md)), so the version migration largely comes for free. What to watch:

- **[VERIFY]** `GoRouterState` accessor renames across 15/16/17.
- **[VERIFY]** redirect signature and `GoRouterRedirect` typedef changes.
- Food is already on 17.3.0 and uses `StatefulShellRoute.indexedStack` successfully — treat food's router as the reference implementation for correct 17.x usage.
- Taxi's `errorBuilder` and the `/search` → `/home/search` redirect both need re-checking against 17's semantics.

### `flutter_local_notifications` 18.0.1 → 22.2.0 — confirmed break

Not a guess — both call sites are in this repo:

```dart
// v18 (taxi) — positional
await _localNotifications.initialize(
  const InitializationSettings(android: androidInit, iOS: iosInit));
await _localNotifications.show(
  notification.hashCode, notification.title, notification.body, details);

// v22 (food) — named
await _localNotifications.initialize(
  settings: initSettings,
  onDidReceiveNotificationResponse: (r) { … });
await _localNotifications.show(
  id: id, title: title, body: body,
  notificationDetails: details, payload: jsonEncode(data));
```

Taxi's `notification_service.dart` is being deleted, so the only real work is **porting taxi's iOS `DarwinInitializationSettings`** into food's init — food's version omits iOS entirely, which means taxi currently has better iOS notification setup than food does.

### `firebase_core` 3 → 4, `firebase_messaging` 15 → 16

**[VERIFY]** both changelogs. Known concerns:

- **Both apps define a top-level `firebaseMessagingBackgroundHandler`.** Only one can exist. Keep food's (it re-initialises Firebase in the isolate, which is required, and taxi's does not — taxi's just logs).
- Taxi calls `Firebase.initializeApp()` with no options inside a swallowing `try/catch`; food falls back to explicit `FirebaseOptions` built from `AppConstants` if the default fails. Keep food's fallback but source the values from `env.dart`.
- Neither app has a generated `firebase_options.dart`. Generating one with the FlutterFire CLI once the surviving project is chosen (B3) is strictly better than the hand-rolled constants both apps use.
- Minimum iOS/Android platform versions may rise. Check `ios/Podfile` and `android/app/build.gradle.kts`.

### `flutter_secure_storage` 9.2.2 → 10.3.1

The two apps configure it **differently, and each has half the right answer**:

```dart
// food — iOS accessibility set, Android default
const FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));

// taxi — Android encrypted prefs set, iOS default
const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true));
```

Merged storage must set **both**. **[VERIFY]** whether v10 changed the default for `encryptedSharedPreferences` and whether it provides a migration path for tokens written by v9 — if not, users of the existing taxi app will be silently logged out on upgrade. That is a release-note item, not just a code item.

### `share_plus` 10 → 13

Three majors, 3 taxi files affected. **[VERIFY]** the current API shape; the package moved from top-level `Share.share()` toward an instance/params form during this range. Food is on 13 and uses it in 5 files — copy food's call style.

### `permission_handler` 11 → 12, `geolocator` 13 → 14

**[VERIFY]** both. Likely Android `targetSdk`/manifest implications. Note food's manifest already declares `FOREGROUND_SERVICE_LOCATION`, `RECORD_AUDIO`, and three Bluetooth permissions that taxi does not — the merged manifest is food's superset ([Ch. 16](10-performance-and-app-size.md)).

### `socket_io_client` 2 → 3

**[VERIFY]**. Both apps use `io.OptionBuilder()`, which has been stable. Taxi's socket is being rebuilt anyway. Watch for `setTransports` and reconnection-option renames.

### `intl` 0.19 → 0.20

`flutter_localizations` pins `intl` transitively; the merged app must use whatever the Flutter SDK version demands. Food is already at 0.20.2 with `flutter_localizations`, so that combination is known-good. Taxi's 2 `intl` files (date/currency formatting) need a compile check only.

---

## 5.7 Native-side dependency implications

Not in `pubspec.yaml`, but they will break the build if missed.

| Item | Food | Taxi | Merged |
|---|---|---|---|
| `compileSdk` | `flutter.compileSdkVersion` | **hardcoded `36`** | Use `flutter.compileSdkVersion`; drop the hardcode |
| `desugar_jdk_libs` | `2.1.4` | `2.0.4` | `2.1.4` — required by `flutter_local_notifications` for scheduled notifications |
| Kotlin JVM target | `kotlinOptions { jvmTarget = 17 }` | `kotlin { compilerOptions { jvmTarget = JVM_17 } }` | Taxi's newer block syntax; both target 17 |
| `kotlin-android` plugin | declared | **not declared** | Declare it — food's form |
| `google-services` plugin | declared | declared | Keep; one `google-services.json` (B3) |
| `manifestPlaceholders["MAPS_API_KEY"]` | present, from env | absent (key hardcoded in manifest) | Adopt food's placeholder approach for **both** keys |
| Release signing | debug keys | debug keys | **Both ship debug-signed.** Must be fixed before any store release |
| iOS `Podfile` | present | **absent** | Taxi has no `Podfile` at the ios root — its iOS build has likely never been exercised. Expect real work here |
| `GoogleService-Info.plist` | absent | absent | Neither app has iOS Firebase configured at all |
| Desktop platforms | none | linux/macos/windows | Delete taxi's |

**The iOS story is worse than the Android story.** Neither app has an iOS Firebase config, food's `AppConstants` has literal placeholder strings (`"ios firebase api key"`, `"ios firebase app id"`), and taxi's iOS Firebase fields are empty strings with a TODO. If iOS is in scope for the super app, treat it as a separate workstream with its own estimate — this document's Android focus reflects the state of the code, not a recommendation.

---

## 5.8 Order of operations

```
1. Both repos, separately:  delete the 14 dead packages. Commit. Verify build.
2. TAXI REPO ONLY:          bump SDK floor, then migrate in this order —
                              a. flutter_local_notifications 18→22   (1 file)
                              b. firebase_core 3→4, messaging 15→16  (2 files)
                              c. socket_io_client 2→3                 (1 file)
                              d. geolocator 13→14, permission_handler 11→12  (2 files)
                              e. flutter_secure_storage 9→10          (1 file) ← test upgrade path
                              f. share_plus 10→13, google_fonts 6→8, intl    (6 files)
                              g. go_router 14→17                      (router + all nav sites)
                              h. flutter_riverpod 2→3                 (12 controllers) ← the big one
                            Ship it. Run the taxi app. Regression-test the full ride flow.
3. FOOD REPO:               rename to superapp_user, adopt the merged pubspec,
                            add hive/connectivity_plus/geocoding/audioplayers/
                            pin_code_fields/smooth_page_indicator/package_info_plus.
                            Verify food still builds and runs unchanged.
4. Merge trees.             Now every import resolves against one version of everything.
```

Step 2 in the taxi repo, standalone and testable, is the whole point. Doing (g) and (h) inside a half-merged tree that does not compile means you cannot tell a migration bug from a merge bug — and there will be dozens of both.
