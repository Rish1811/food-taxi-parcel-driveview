# Chapters 16 & 17 — Performance and App Size

---

# Chapter 16 — Performance

## 16.1 The three things a merge makes worse by default

1. **Cold start** — both apps' boot work runs, serially, before the first frame.
2. **Resident memory** — one root `ProviderScope` holding four modules' controllers, two map contexts, two image caches.
3. **Widget rebuilds** — food's mutable `AppColors.primary` mechanism rebuilds `MaterialApp` (and therefore everything) on a theme-colour change, which now includes a live map and two sockets.

Everything below is aimed at these three, in that order.

## 16.2 Deferred initialisation

### Measured current boot work

**Food's `main.dart` + root widget:**
```
ensureFirebaseInitialized()                          network + native
FirebaseMessaging.onBackgroundMessage(handler)
runApp
  → ScreenUtilInit
  → addPostFrameCallback:
      pushService.initialize()   ← permission prompt, getToken (network),
                                    POST token to backend, 4 stream subscriptions,
                                    local-notification channel creation
      pushService.performAppStartCheck()  ← another getToken + another POST
```

**Taxi's `main.dart`:**
```
LocalStorageService().init()   ← Hive.initFlutter + open 5 boxes  (disk I/O ×5)
SecureStorageService()
Firebase.initializeApp()
runApp
  → addPostFrameCallback: notificationService.init()   ← permission, getToken
```

Merged naively: 5 Hive boxes + Firebase + 2 push inits + 2 permission prompts + 2 token POSTs + 2 socket connects, before the hub renders.

### Target tiers

| Tier | When | What | Why |
|---|---|---|---|
| **0** | blocking, pre-`runApp` | `SharedPreferences` open · `TokenStorage` construct (no I/O — it reads lazily) · cached feature flags · **theme mode** | Theme mode must be Tier 0 or the app flashes light-then-dark |
| **1** | parallel, pre-first-frame | `Firebase.initializeApp()` · `ConnectivityService.start()` · background-handler registration | All failure-tolerant; `Future.wait` them |
| **2** | post-first-frame | session restore (`GET /me`) · push permission + token registration · feature-flag refresh · socket connect **if logged in** | Nothing here blocks pixels |
| **3** | `AppModule.warmUp()`, on first module entry | module's Hive boxes · Maps SDK warm-up · catalogue/vehicle-type prefetch · module socket rooms | The user has now expressed intent |

Specific wins over today:

- **4 of 5 Hive boxes leave the critical path.** Only `settings` is needed at Tier 0; `recentSearches`, `savedAddresses`, `emergencyContacts`, `favoriteDrivers` are Tier 3, opened by the module that needs them.
- **Notification permission moves off first frame.** Both apps prompt immediately. In a super app, prompting before the user has chosen a service is slower *and* worse UX — and a denied prompt is expensive to recover from. Ask when they first place an order or book a ride. Taxi already has a proper `notification_permission_screen.dart` for exactly this.
- **One push init, one token POST.** Food currently calls `getToken()` and POSTs twice on a logged-in launch (once in `initialize()`, once in `performAppStartCheck()`).
- **Sockets connect at Tier 2, not eagerly.** And only for endpoints whose modules are enabled.

### Measurement

Instrument before optimising. Add `Timeline.timeSync` around each tier and track:

```
flutter run --profile --trace-startup
# → build/start_up_info.json
#   timeToFirstFrameRasterizedMicros  ← the number that matters
```

Baseline both apps standalone first, in Phase 0. Without a baseline you cannot tell whether the merged app regressed.

## 16.3 Lazy module loading

Two distinct meanings; both apply.

### Runtime laziness — do this

Module code is only *executed* on entry. Delivered by module `ProviderScope` + `warmUp()` (Ch. 2 §2.5–2.6) + `registry.enabled(flags)`. No build-system work. This is where the real win is.

### Binary laziness (deferred components) — evaluate, don't assume

Flutter supports deferred loading via `import '…' deferred as x` + Play Feature Delivery. Constraints that matter here:

- **Android only** for native builds. iOS does not support deferred components. So it cannot be the primary size strategy for a cross-platform app.
- Requires `--split-debug-info`, deferred-component declarations in `pubspec.yaml`, and Play-side feature-module configuration.
- **Dart code is a small fraction of this app's size.** ~69k lines of Dart compiles to a few MB of AOT snapshot; the assets are 29 MB and the native plugins (Maps, Firebase, WebView, video, Razorpay) are larger still. Deferring Dart while shipping 2.2 MB PNGs is optimising the wrong end.
- `go_router` route builders referencing a deferred library need care — the route table itself must not force the library to load.

**Recommendation:** implement runtime laziness in Phase 3. Revisit deferred components only after the asset pass (§17.4), and only if a measured AAB shows Dart snapshot size actually mattering. Deferring **assets** via Play asset packs is the more promising variant, and it works without touching Dart.

## 16.4 Image optimisation

| Issue | Evidence | Fix |
|---|---|---|
| `markerbike.png` **2.2 MB** for a map marker | `flutter_taxi_user/assets/` | WebP at rendered size. `markerauto.webp` is 200 KB and `markersedan.webp` is 224 KB — the target is already established |
| `Delivery.png` **1.5 MB**, `Ridenow.png` **1.5 MB** | ditto | WebP, and check whether they need to be full-bleed |
| 20 further PNGs at 300 KB–1.3 MB | `search.png` 1.3 MB, `banner.png` 912 KB, `ride_now_banner.png` 888 KB, `outstation_service.png` 868 KB, … | Batch WebP conversion |
| No resolution variants | neither app has `2.0x/` `3.0x/` folders | Ship one WebP at 3× and let Flutter downscale, or add variants for the largest few |
| `cached_network_image` without size hints | food 1 file (via `smart_image`), taxi 8 files | Always pass `memCacheWidth`/`memCacheHeight`. Without them a 2000 px remote image is decoded at full size into memory for a 120 px thumbnail |
| Marker bitmaps decoded repeatedly | both apps | `MarkerFactory` cache keyed by (asset, size, heading bucket) |
| `ImageCache` unbounded across modules | new to the merge | Set `PaintingBinding.instance.imageCache.maximumSizeBytes` explicitly (~100 MB), and `.clear()` on module exit for module-specific art |

Food's `smart_image.dart` (91) and `image_pools.dart` (48) are the right foundation — they just need to be the *only* way images load, and they need size hints threaded through.

## 16.5 Memory

| Concern | Mitigation |
|---|---|
| Four modules' controllers resident | Module `ProviderScope` disposal (Ch. 8 §8.4) — the single biggest lever |
| Two `GoogleMapController`s | `AppMap` disposes on route exit; module scope teardown enforces it |
| ~7 MB vehicle catalogue | Use the slim `/users/vehicle-map-icons` feed (taxi's own comment explains why it exists); cache to disk, not memory |
| Food's `order_model.dart` (747 lines) held per order in a long list | Paginate; keep a summary DTO for lists and the full model only for the open detail |
| Two socket connections buffering | `pauseAll()` on background |
| Image cache | §16.4 |
| 1,313 lines of legal text as `const String` | Move to CMS (also a size win) |

Profile with DevTools' memory view after Phase 5, holding a food order and a live ride simultaneously — that is the worst case, and it is a state neither app has ever been in.

## 16.6 Widget rebuild optimisation

### The mutable-statics problem

Food's `ThemeColorNotifier` reassigns `AppColors.primary`, then bumps `state`; the root watches `themeColorProvider` and rebuilds `MaterialApp`. That means **the entire widget tree rebuilds** for a colour change. Today that is tolerable. With a live map and two sockets it is a visible hitch.

`ThemeExtension` + module-subtree `Theme` (Ch. 6 §6.11) fixes this: only widgets that actually read `context.palette` rebuild, and a module accent change is scoped to that module's subtree.

### Other rebuild wins

| Issue | Where | Fix |
|---|---|---|
| Whole-object `ref.watch` | both apps | `ref.watch(p.select((s) => s.field))` — food's shell watches whole cart state to read `items.isNotEmpty` |
| `AnimatedBuilder` on `router.routerDelegate` | food's `MainAppShell` | Rebuilds the shell on every navigation. Use `GoRouterState.of(context)` or a `select` on the location |
| Non-`const` constructors in list items | `restaurant_card.dart` (1,220), `ride_card.dart` (220) | `const` where possible; extract sub-widgets so a parent rebuild doesn't rebuild leaves |
| 1,000+ line screens as one `build()` | `cart_screen` 2,629, `profile_screen` 1,974, `restaurant_screen` 1,599, `home_screen` (taxi) 1,380 | Split into `const`-able sub-widgets. Not a merge task, but the biggest available frame-time win in the food module |
| `ListView` without `itemExtent` | both | `itemExtent` or `prototypeItem` on fixed-height lists |
| Missing `RepaintBoundary` | map overlays, floating cards | Wrap anything animating over static content |
| Overscroll glow removal | taxi's `_AppScrollBehavior` | Keep it — it also avoids a needless overlay layer |

**Do not attempt the 1,000-line screen splits during the merge.** They are the right work, they are large, and mixing them with a migration makes review impossible. Schedule them after Phase 8, per screen, with before/after frame timings.

## 16.7 Navigation performance

| Item | Note |
|---|---|
| `StatefulShellRoute.indexedStack` | Food already uses it; taxi's per-screen `context.go()` rebuilds destinations from scratch. Per-module shells (Ch. 7 §7.5) fix this |
| `indexedStack` keeps all branches alive | Correct for food's 4 tabs (state preservation is the point); do **not** add branches casually — each is a resident tree |
| Module transitions | Use a plain fade, not a heavy custom transition; module entry may coincide with `warmUp()` |
| Loader screens | Food's pattern (`RestaurantDetailLoaderScreen`) shows a skeleton immediately instead of blocking navigation on a fetch. Apply to every id-only route |

## 16.8 API caching and offline

Food's cache interceptor is already good. Two changes:

- **Policy table** (Ch. 9 §9.6) so four modules behave consistently, and money/mutable data is never cached.
- **Move the cache off `SharedPreferences`.** `_CacheInterceptor._persist()` currently re-serialises the *whole* cache to one `SharedPreferences` string on every write. That is fine for "a handful of discovery endpoints" (its own comment) but with four modules it becomes a large synchronous-ish JSON encode on a hot path. Move to a Hive box keyed per entry — Hive is already a dependency, and per-key writes remove the re-serialise-everything cost.

Offline behaviour worth keeping and generalising: `onError` resolving from cache regardless of age. "Something on screen beats a failure toast" is right for a restaurant list. It must **not** apply to wallet, cart, orders, or rides.

## 16.9 The Impeller decision

Food's manifest:

```xml
<meta-data android:name="io.flutter.embedding.android.EnableImpeller"
           android:value="false" />
```

with a comment citing `flutter/flutter#137639` and `#142082`: Impeller's Vulkan backend had a bug where `video_player`'s external texture rendered once and never updated, so playback looked frozen.

Taxi does not set it, so taxi has always run **with** Impeller — including its 12 map files.

The merged app must choose one, and neither choice is free:

| Choice | Risk |
|---|---|
| Impeller **off** (food's setting) | Taxi's maps and animations have never been tested on Skia. Map scroll/zoom performance is the thing most likely to regress, and it is the most visible surface in the taxi module |
| Impeller **on** | Food's 3 `video_player` usages may show frozen playback on affected devices |

**Recommended approach:** re-test rather than inherit. The referenced Impeller/`video_player` issues are from earlier Flutter versions; verify against the SDK you actually pin (the merged floor is `^3.12.2`). If video works with Impeller on, enable Impeller — taxi's map-heavy screens are the larger and more frequently used surface. If it still breaks, keep Impeller off and profile taxi's maps on Skia specifically, on a mid-range device, before shipping.

Add this to the Phase 8 gate as an explicit test: video playback on 3 devices × map scroll/zoom on 3 devices, both Impeller states.

## 16.10 Connectivity polling

Food's `network_status_provider.dart` runs `InternetAddress.lookup` on a **5-second `Timer.periodic`**, forever. That is a wakeup every 5 s for the app's entire lifetime, plus a DNS query.

Replace with `connectivity_plus` (already in taxi's pubspec): react to the OS's connectivity stream, and do one reachability probe on change. Zero polling, faster detection, less battery. Straight win, one file.

---

# Chapter 17 — App Size

## 17.1 The premise in the brief, checked

The brief states: taxi ≈40 MB, food ≈45 MB, merged **not** 85 MB but ~50–60 MB, because Flutter SDK, Firebase, Maps, Dio, Socket.IO, image cache, SharedPreferences and Hive are included once.

**The reasoning is correct.** Shared dependencies are counted once, so the merged binary is much closer to `max(A, B)` than `A + B`. Two corrections though:

1. **Assets do not dedupe.** Food's 12 MB and taxi's 17 MB are almost entirely distinct images. That is **29 MB of assets** carried into one binary. Uncompressed, the merged app is likely *above* the 50–60 MB estimate, not below it — assets are the dominant term here, not libraries.
2. **The 40/45 MB figures could not be verified** — no build outputs exist in this workspace, and both apps are debug-signed with no release config. Treat them as reported, and establish real baselines in Phase 0.

## 17.2 What actually contributes

| Component | Shared? | Note |
|---|---|---|
| Flutter engine + Dart AOT runtime | **once** | The largest fixed cost, and the source of the brief's insight |
| Dart AOT snapshot (~69k lines) | grows | Roughly additive but small relative to everything else |
| `google_maps_flutter` native | **once** | Large; both apps ship it |
| Firebase (core + messaging + database) | **once** | `firebase_database` is food-only and non-trivial |
| `webview_flutter` | **once** | Food-only; large |
| `video_player` | **once** | Food-only |
| `razorpay_flutter` native SDK | **once** | Both |
| `speech_to_text`, `geolocator`, `geocoding`, `image_picker`, `permission_handler`, `connectivity_plus`, `audioplayers`, `package_info_plus`, `hive` | **once** | Mostly small |
| `google_fonts` | **once** | ⚠ Fetches at runtime and caches to disk — so it inflates *installed* size, not download size, unless fonts are bundled |
| Bundled font `ManropeVariable` | 164 KB | Food-only |
| **Assets** | **additive** | food 12 MB + taxi 17 MB = **29 MB** |
| Legal text as `const String` | additive | 1,313 lines compiled in |

So: libraries argue for ~`max(A,B)`; assets argue for `A+B`. The asset pass is therefore the whole ball game.

## 17.3 Estimation method (not a guess)

Do this in Phase 0 and again at Phase 8:

```bash
# per-app baseline, release AAB
flutter build appbundle --release --analyze-size \
  --target-platform android-arm64
# → writes a size analysis JSON; open it in DevTools' App Size tool

# per-ABI APK, for a like-for-like comparison with what users download
flutter build apk --release --split-per-abi --analyze-size
```

Record for each app: AAB size, per-ABI APK size, Dart snapshot size, asset bundle size, native library size. Then the merged number is predictable rather than argued about, and Phase 8's target is measurable.

**Note on the brief's `--split-per-abi` advice:** that flag applies to `flutter build apk`, not `appbundle`. An AAB already contains all ABIs and Play generates per-device splits automatically — so for Play Store delivery `appbundle --release` alone is correct, and `--split-per-abi` is only useful for direct-APK distribution or local size comparison. The brief's recommendation to ship an AAB is right; the split-ABI part is a testing tool, not a release step.

## 17.4 The asset pass — the highest-value size work

### Step 1: stop bundling whole directories

Both apps declare directories wholesale:

```yaml
# taxi — bundles all 33 root PNGs, including a 2.2 MB marker
assets:
  - assets/
  - assets/audio/

# food
assets:
  - assets/
  - assets/images/
  - assets/videos/
  - assets/gif/
```

`- assets/` means every file in it ships, forever, including anything a designer dropped there. Restructure and enumerate:

```
assets/
├── brand/          app_icon · logo variants
├── images/
│   ├── food/       restaurant placeholders, category art
│   ├── taxi/       vehicle art, service tiles
│   ├── parcel/
│   └── shared/     empty states, onboarding, illustrations
├── markers/        map markers only, WebP, at rendered size
├── audio/
├── gif/
├── videos/
└── fonts/
```

### Step 2: re-encode

| Asset | Now | Action | Est. after |
|---|---|---|---|
| `markerbike.png` | 2.2 MB | WebP at marker size | ~200 KB |
| `Delivery.png` | 1.5 MB | WebP | ~180 KB |
| `Ridenow.png` | 1.5 MB | WebP | ~180 KB |
| `search.png` | 1.3 MB | WebP, or replace with an icon | ~100 KB |
| `banner.png` | 912 KB | WebP | ~120 KB |
| `ride_now_banner.png` | 888 KB | WebP | ~120 KB |
| `outstation_service.png` | 868 KB | WebP | ~110 KB |
| `promo_car_banner.png` | 668 KB | WebP | ~90 KB |
| `top_map_bg.png` | 588 KB | WebP | ~80 KB |
| `parcel_service.png` | 548 KB | WebP | ~70 KB |
| `auto_cat.png` | 552 KB | WebP | ~70 KB |
| `bike_service.png` | 532 KB | WebP | ~70 KB |
| `delivery_rider_banner.png` | 520 KB | WebP | ~70 KB |
| `taxi_service.png` | 508 KB | WebP | ~70 KB |
| `movers_cat.png` | 472 KB | WebP | ~60 KB |
| `bottom_truck_bg.png` | 444 KB | WebP | ~60 KB |
| `scooter_cat.png` | 404 KB | WebP | ~55 KB |
| `truck_cat.png` | 384 KB | WebP | ~50 KB |
| `logo.png` | 296 KB | WebP / SVG | ~40 KB |
| remaining ~12 taxi PNGs | ~1.5 MB total | WebP | ~250 KB |
| **taxi assets** | **17 MB** | | **~2.5 MB** |
| food `gif/` | 3.3 MB | Replace GIFs with WebP animation or Lottie JSON | ~600 KB |
| food `videos/` | 3.2 MB | **Stream from CDN, don't bundle** | ~0 |
| food `images/` | 4.6 MB | WebP pass | ~900 KB |
| food `audio/` + taxi `audio/` | 324 KB | keep | ~324 KB |
| food `font/` | 164 KB | keep (subset if possible) | ~120 KB |
| **food assets** | **12 MB** | | **~1.9 MB** |
| **TOTAL** | **29 MB** | | **~4.4 MB** |

**~25 MB removed from the asset bundle.** That single pass dwarfs every other size optimisation available, and it requires no architectural change — it can be done in Phase 1, in parallel with everything else.

Two specifics worth calling out:

- **The 3.2 MB of bundled video is the easiest win.** A promotional video does not belong in the binary; `video_player` streams from a URL perfectly well, and it lets marketing change the video without a release.
- **Animated GIFs are the worst format available.** 3.3 MB of GIF becomes a few hundred KB as animated WebP, and Flutter decodes it more cheaply too.

### Step 3: audit for duplicates

Both apps ship their own empty-state art, loading indicators, onboarding illustrations, app icons, and placeholder images. After consolidating into `shared/`, expect to delete a further handful of near-duplicates. Compare by perceptual hash, not filename — they will not be named the same.

### Step 4: fonts

Food: Poppins via `google_fonts` (runtime download + disk cache) **plus** a bundled `ManropeVariable` (164 KB). Taxi: `'Roboto'` (a system font on Android, so free).

Decide one text style ([Ch. 6 §6.11](05-shared-components.md)). If the answer is Poppins, consider **bundling a subsetted Poppins** instead of `google_fonts` — a runtime font fetch means the first launch renders in a fallback font and then reflows, which looks cheap. If the answer is Manrope, drop `google_fonts` entirely and save a dependency.

## 17.5 Build configuration

```bash
# Play Store release
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.suvio.com/api/v1 \
  --dart-define=SOCKET_URL=https://api.suvio.com \
  --dart-define=MAPS_API_KEY=… \
  --obfuscate --split-debug-info=build/symbols

# local size comparison only
flutter build apk --release --split-per-abi --analyze-size
```

| Setting | Status | Action |
|---|---|---|
| Release signing | **both apps sign release with debug keys** | Must be fixed before any store release. Create a keystore, wire `signingConfigs`, keep the keystore out of git |
| `--obfuscate --split-debug-info` | not used | Enable. Modest size win, meaningful IP protection, and symbol files let you still symbolise crashes |
| R8 / shrinking | Flutter's Android release default | Verify it is actually on; add `proguard-rules.pro` keeps for Razorpay and any reflection-based SDK |
| `compileSdk` | food uses `flutter.compileSdkVersion`; **taxi hardcodes 36** | Use the Flutter-provided value |
| `desugar_jdk_libs` | 2.1.4 (food) vs 2.0.4 (taxi) | 2.1.4 |
| `minSdk` | both `flutter.minSdkVersion` | Confirm the floor; `hive`, `firebase`, and `google_maps_flutter` all have opinions |
| Unused native plugins | 14 dead Dart packages ([Ch. 5 §5.2](04-dependency-merge.md)) | Deleting them removes their native code too — `fl_chart`, `lottie`, `flutter_svg` are pure Dart, but `device_info_plus` and `path_provider` carry native pieces |

## 17.6 Realistic size expectation

Given libraries dedupe and assets do not:

| Scenario | Asset bundle | Expected outcome |
|---|---|---|
| Naive merge, no asset work | 29 MB | **Above** the brief's 50–60 MB estimate. Assets alone add ~29 MB on top of a shared engine + native baseline |
| Merge + asset pass (§17.4) | ~4.4 MB | Comfortably **at or below** the smaller of the two current apps, despite carrying four modules |
| Merge + assets + obfuscation + AAB + CMS legal text | ~4.4 MB | Best case; a genuinely smaller download than either app ships today |

The brief's optimism about library sharing is well-founded. The thing it under-weights is that **29 MB of unshared assets is the dominant term**, and that it is also the easiest to fix. Do the asset pass early — it is independent of the architecture work, it can run in parallel, and it is worth more than every other size optimisation combined.

## 17.7 Checklist

**Performance**
- [ ] Baseline `--trace-startup` for both apps, standalone (Phase 0)
- [ ] Tiered `bootstrap()`; Hive boxes lazy per module
- [ ] Notification permission moved off first frame
- [ ] One push init, one token POST per launch
- [ ] Module `ProviderScope` disposal verified with DevTools memory
- [ ] `connectivity_plus` replaces the 5 s DNS poll
- [ ] `ThemeExtension` replaces mutable `AppColors` statics
- [ ] `MarkerFactory` bitmap cache with heading buckets
- [ ] `memCacheWidth/Height` on every `cached_network_image`
- [ ] `imageCache.maximumSizeBytes` set explicitly
- [ ] API cache moved from `SharedPreferences` blob to per-key Hive
- [ ] Cache policy table applied; nothing mutable or monetary cached
- [ ] Sockets pause on background
- [ ] Impeller decision **re-tested**, not inherited (video × 3 devices, maps × 3 devices)
- [ ] Worst-case profile: live food order + live ride simultaneously

**Size**
- [ ] `--analyze-size` baselines recorded (Phase 0)
- [ ] 14 dead dependencies deleted
- [ ] No wholesale `- assets/` declarations
- [ ] All 20 oversized PNGs → WebP at rendered size
- [ ] 3.2 MB of video moved to CDN streaming
- [ ] 3.3 MB of GIF → animated WebP
- [ ] Duplicate art deduplicated by perceptual hash
- [ ] Font decision made; `google_fonts` runtime fetch reconsidered
- [ ] 1,313 lines of legal text moved to CMS
- [ ] Release keystore created; debug signing removed
- [ ] `--obfuscate --split-debug-info` enabled
- [ ] AAB for Play; `--split-per-abi` used for comparison only
- [ ] Final `--analyze-size` vs. baseline, per module
