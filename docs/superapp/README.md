# Document 1 — Flutter Super-App Integration Guide

**Scope:** merging `flutter_taxi_user` (UdanX) into `Food_user/flutter-food-user-application` (Suvio) to produce one Flutter super app with `food`, `taxi`, `parcel` and `rental` modules.

**Status:** research + architecture only. **No code has been written or moved.** Implementation begins once the merged backend is supplied.

---

## 0.1 How to read this document

| Chapter | File | What it answers |
|---|---|---|
| 1 | [01-project-analysis.md](01-project-analysis.md) | What each app actually is today — measured, not assumed |
| 2 | [02-target-architecture.md](02-target-architecture.md) | The target `lib/` tree and the `AppModule` contract that makes modules pluggable |
| 3, 4 | [03-file-migration-map.md](03-file-migration-map.md) | Every file: move / merge / rewrite / delete |
| 5 | [04-dependency-merge.md](04-dependency-merge.md) | `pubspec.yaml` reconciliation, version conflicts, dead packages |
| 6 | [05-shared-components.md](05-shared-components.md) | Profile, wallet, address, support, notifications, payment, language, offers, referral, settings, theme |
| 7 | [06-routing-and-navigation.md](06-routing-and-navigation.md) | Route namespacing, collision table, shell design, deep links |
| 8 | [07-state-management-and-di.md](07-state-management-and-di.md) | Riverpod 2 → 3 migration, provider scoping, controller ownership |
| 9, 10, 11 | [08-api-socket-push.md](08-api-socket-push.md) | API layer, Socket.IO multiplexing, unified FCM parser |
| 12–15 | [09-maps-search-wallet-activity.md](09-maps-search-wallet-activity.md) | Maps, unified search, one wallet, one Activity page |
| 16, 17 | [10-performance-and-app-size.md](10-performance-and-app-size.md) | Startup, memory, rebuilds, caching, APK/AAB size |
| 18 | [11-execution-runbook.md](11-execution-runbook.md) | Phase-by-phase, folder-by-folder migration checklist with gates |
| 19 | [12-adding-a-new-module.md](12-adding-a-new-module.md) | **Playbook for manually adding a 5th module later** (bus, grocery, hotel…) — 13 steps, templates, verification, mistakes to avoid |
| 20 | [13-driver-identity-bridge.md](13-driver-identity-bridge.md) | **Blocker for the food+taxi driver app** — why a delivery-partner token is refused by `/taxi/*`, the two-file k9 patch, and the backfill that populates the link |

Everything in Chapter 1 is **measured from the actual source tree**. Where a claim needs verification against a package changelog at pin time, it is marked **[VERIFY]**.

---

## 0.2 Executive summary

The two apps are not two halves of one app. They are two independently-built products that happen to solve similar problems in incompatible ways:

| | Food (Suvio) | Taxi (UdanX) |
|---|---|---|
| Dart files / lines | **212 / 51,724** | **173 / 23,083** |
| Architecture | Layered (`src/core`, `src/data`, `src/domain`, `src/di`, `src/platform`, `src/presentation`) | Feature-first (`core`, `features/<f>/{application,data,presentation}`, `shared`) |
| State management | Riverpod **3.3.2** — `Notifier` / `AsyncNotifier` | Riverpod **2.6.1** — `StateNotifier` in 12 files |
| Router | `go_router` **17.3.0**, `Provider<GoRouter>` | `go_router` **14.6.2**, global `final appRouter` |
| Backend | `https://suvio.appzeto.com/api/v1`, paths under `/food/*` | `https://taxi.appzeto.com/api/v1`, paths under `/users/*`, `/rides/*`, `/deliveries/*` |
| Auth | access + refresh JWT pair, single-flight refresh | single opaque token, **no refresh** |
| Firebase project | `flutterfoodapp-e6742` (+ RTDB) | `appzet-taxi` |
| Package id | `com.fooduser.app` | `com.supertaxi.user` |
| Maps key | `AIzaSyCLHQ…` | `AIzaSyArBb…` |
| Local storage | `flutter_secure_storage` + `SharedPreferences` | `flutter_secure_storage` + **Hive** (5 boxes) |
| Assets on disk | 12 MB | 17 MB |
| Localisation | `l10n.yaml` + generated delegate, **used in 3 files** | locale code persisted, **no delegates at all** |

The merge is therefore **not a file-copy exercise**. It is four separate pieces of work, in this order:

1. **Unify the platform layer** (network, auth, socket, push, storage, theme) — the part both apps duplicate badly.
2. **Migrate the taxi app forward** to Riverpod 3 / go_router 17 / Firebase 4 / local-notifications 22 — the version gap is where the real cost is.
3. **Namespace both feature sets** as pluggable modules behind one contract.
4. **Collapse the shared features** (profile, wallet, address, notifications, support, activity) into one implementation each.

Steps 1–3 can be done before the merged backend exists. Step 4 cannot — it depends on backend decisions listed in §0.4.

---

## 0.3 The ten findings that shape the whole design

These are the things that would derail a naive merge. Each is measured, with the evidence cited.

### 1. Two Firebase projects, one `google-services.json` slot

`flutter_taxi_user/android/app/google-services.json` → project `appzet-taxi` (`147333377409`).
`Food_user/.../android/app/google-services.json` → project `flutterfoodapp-e6742` (`592916974677`).

An Android app can carry exactly one `google-services.json`, therefore exactly one FCM sender. **One project must win, and the losing backend must be re-credentialed to send through it.** Food additionally uses Firebase **Realtime Database** (`active_orders/{orderId}`, `src/data/datasources/order_rtdb_datasource.dart`) bound to `flutterfoodapp-e6742-default-rtdb`, so picking the taxi project means recreating that RTDB and repointing the food dispatch writer.

→ Recommendation and migration path: [08-api-socket-push.md §11](08-api-socket-push.md).

### 2. 20 public class names collide

Measured by scanning class declarations in both trees:

```
AboutScreen        ApiClient          AppColors         AppConstants
AppTextStyles      AuthRepository     AuthSession       EditProfileScreen
HomeScreen         LocationService    NotificationsScreen  OtpScreen
PrimaryButton      ProfileScreen      ProfileSetupScreen   SocketService
SplashScreen       UserModel          WalletRepository  WalletScreen
```

…plus 24 colliding **file names** (`api_client.dart`, `app_colors.dart`, `app_theme.dart`, `user_model.dart`, `socket_service.dart`, `theme_provider.dart`, …) and 6 colliding **top-level Riverpod globals** (`apiClientProvider`, `authRepositoryProvider`, `locationServiceProvider`, `rootNavigatorKey`, `socketServiceProvider`, `walletRepositoryProvider`).

Import aliasing would "fix" this and leave the app permanently unmaintainable. Every collision must be resolved by **choosing a winner or renaming to a module-qualified name** — the table is in [03-file-migration-map.md](03-file-migration-map.md).

### 3. `AppColors.primary` is mutable in food and `const` in taxi

Food deliberately made `AppColors.primary` and `AppColors.primaryButton` **non-const static fields** so `ThemeColorNotifier` can reassign them and repaint 1,125 read sites without each one watching a provider (`src/presentation/branding/theme_color_provider.dart`).

Taxi's `AppColors.primary` is `static const` and is used inside **55 `const` expressions** (`const BorderSide(color: AppColors.primary)`, `const ColorScheme.light(primary: AppColors.primary)`).

These two designs are mutually exclusive. You cannot merge the classes without editing one side. Also note the brands differ: food orange `0xFFFF7A00`, taxi orange `0xFFFF5C2B`.

→ Resolution (theme extensions + per-module accent, no mutable statics): [05-shared-components.md §6.11](05-shared-components.md).

### 4. Taxi's state management is a version behind, structurally

`StateNotifier` / `StateNotifierProvider` appear in **12 taxi files**. Food uses `Notifier` (23 files) and `AsyncNotifier` (3 files) — the Riverpod 3 idiom. `StateNotifier` is legacy in Riverpod 2.x and is not part of the 3.x surface **[VERIFY against the 3.x changelog at pin time]**.

Because the merged app can only resolve **one** version of `flutter_riverpod`, this is not optional and cannot be deferred: 12 taxi controllers must be rewritten before the taxi module compiles inside the merged app.

### 5. `flutter_local_notifications` changed its call signature between the two pinned versions

Observed directly in source, not inferred:

```dart
// food — v22 (named arguments)
await _localNotifications.initialize(settings: initSettings,
    onDidReceiveNotificationResponse: (r) { … });
await _localNotifications.show(id: id, title: title, body: body,
    notificationDetails: details, payload: jsonEncode(data));

// taxi — v18 (positional arguments)
await _localNotifications.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit));
await _localNotifications.show(notification.hashCode, notification.title,
    notification.body, NotificationDetails(...));
```

Taxi's `NotificationService` will not compile against v22. It is a rewrite, not a move.

### 6. The two Android manifests conflict on three single-valued keys

| Key | Food | Taxi |
|---|---|---|
| `com.google.android.geo.API_KEY` | `AIzaSyCLHQ…` | `AIzaSyArBb…` |
| `firebase.messaging.default_notification_channel_id` | `high_importance_channel` | `ride_updates` |
| `io.flutter.embedding.android.EnableImpeller` | `false` (set to fix a `video_player`/Vulkan bug) | not set (Impeller on) |

All three are one-value-per-app. The Impeller one is the interesting trade: food disabled Impeller to fix frozen video playback, and taxi's map-heavy screens have never been tested with Impeller off.

→ [10-performance-and-app-size.md §16.9](10-performance-and-app-size.md).

### 7. The backend path namespaces do **not** collide — this is the good news

Food mounts everything under `/api/v1/food/*`. Taxi mounts under `/api/v1/{users,rides,deliveries,promos,support,common}/*` (confirmed: `backend/taxi-new/Backend/src/app.js` → `app.use('/api/v1', taxiRouter)`).

So a merged backend can host both route trees on one host with **zero path rewriting**. What does *not* survive the merge is **identity**: food issues an access/refresh pair from `/food/auth/user/verify-otp`; taxi issues a single `token` from `/users/auth/verify-otp`. One user, one session, one token — that is a backend decision the client cannot paper over.

### 8. "One wallet" is a backend guarantee, not a client feature

Food's wallet model is 378 lines (balance, cashback ledger, refunds, cashback settings). Taxi's is 32 lines plus top-up/transfer/Razorpay/PhonePe endpoints. Two ledgers on two hosts.

A client that fetches two balances and adds them is a financial bug: it can show money that cannot be spent on the other side, and concurrent debits will disagree. The client design in [09-maps-search-wallet-activity.md §14](09-maps-search-wallet-activity.md) reads **one** authoritative balance and treats per-module history as a read-only merged view.

### 9. Neither app is actually localised

Food has the scaffolding (`l10n.yaml`, `generated/l10n/app_localizations.dart`, `flutter_localizations`) but `AppLocalizations` is referenced in **3 files** out of 212 — the other ~51k lines are hardcoded English. Taxi persists a language code and lists five languages (`en, hi, ta, te, kn`) with **no ARB files and no delegates** — the Language screen is decorative.

So Chapter 6's "Language" item is not a merge task. It is a greenfield workstream sized at roughly 51k + 23k lines of string extraction. Treat it as post-merge, and do not let it block the merge.

### 10. Both pubspecs carry dead weight

Measured `import` counts against declared dependencies:

**Food declares but never imports:** `freezed_annotation`, `json_annotation` (and dev: `freezed`, `json_serializable`, `build_runner`) — 0 files, 0 generated `.g.dart`/`.freezed.dart`. Also `flutter_launcher_icons` is in `dependencies` instead of `dev_dependencies`, with no config block.

**Taxi declares but never imports:** `flutter_rating_bar`, `logger`, `device_info_plus`, `lottie`, `flutter_svg`, `fl_chart`, `equatable`, `shared_preferences` (direct), `path_provider` (direct) — 0 files each.

That is 9 packages in taxi and 5 in food that can be deleted before the merge even starts, which shrinks the conflict surface for free.

---

## 0.4 Open questions the backend merge must answer

These block Step 4 (collapsing shared features). Answer them when you hand over the merged backend; each one has a client design waiting on it.

| # | Question | Why the client cannot decide it | Chapter |
|---|---|---|---|
| B1 | One `users` collection or two, joined by phone? | Determines whether `UserModel` is one type or a shared core + per-module profile | [08 §9](08-api-socket-push.md) |
| B2 | One JWT for both route trees? Access+refresh, or single token? | Determines whether `ApiClient` needs one token store or two, and whether refresh exists at all | [08 §9](08-api-socket-push.md) |
| B3 | Which Firebase project survives? | One `google-services.json`; also decides whether food's RTDB tracking node moves | [08 §11](08-api-socket-push.md) |
| B4 | Does every push payload carry a `module` discriminator (`"food"`/`"taxi"`/`"parcel"`)? | Without it, the unified notification parser has to guess from `type` string prefixes | [08 §11](08-api-socket-push.md) |
| B5 | One Socket.IO server, or two hosts during transition? Namespaces or event prefixes? | Decides one connection vs. a gateway managing two | [08 §10](08-api-socket-push.md) |
| B6 | One wallet ledger, or two with a transfer bridge? | Decides whether "one wallet" is real or a display fiction | [09 §14](09-maps-search-wallet-activity.md) |
| B7 | Is there a unified `GET /activity` (cursor-paginated, mixed types), or does the client fan out and merge? | Decides whether the Activity page can paginate correctly at all | [09 §15](09-maps-search-wallet-activity.md) |
| B8 | One address book, or food addresses + taxi saved places separately? | Food has `/food/user/addresses`; taxi keeps saved places in a **local Hive box** | [05 §6.3](05-shared-components.md) |
| B9 | One promo/coupon engine? Food uses `/food/restaurant/offers`, taxi `/promos/validate`. | Decides whether one coupon sheet can serve both carts | [05 §6.8](05-shared-components.md) |
| B10 | One support ticket queue? Food has `/food/chat/*` + help screens; taxi has `/support/tickets` + SOS. | Decides one Support module or two | [05 §6.4](05-shared-components.md) |

**Until B1–B3 are settled, the merged app must be built to run against two backends simultaneously.** The architecture in Chapter 2 is designed for exactly that, so that unifying the backend later is a configuration change, not a refactor. That is the single most important design constraint in this document.

---

## 0.5 Decision log

Decisions taken in this document, with the reason. Reverse any of them deliberately, not by accident.

| ID | Decision | Reason |
|---|---|---|
| D1 | **Food is the host project**; taxi migrates into it | Food is 2.2× the code, on newer everything, and has the stronger platform layer (`ApiClient` with single-flight refresh, typed failures, disk-backed GET cache) |
| D2 | Target tree is `core` / `design_system` / `shared` / `modules` — **not** food's `src/` layering, **not** taxi's `features/` | Neither existing shape distinguishes "platform", "cross-module feature", and "module". That distinction is the whole point of a super app |
| D3 | Modules are registered through an `AppModule` contract, not wired ad hoc | Routing, push routing, socket bindings, activity feed and search all need per-module contributions. One contract instead of five switch statements |
| D4 | Every module route is namespaced (`/food/*`, `/taxi/*`, `/parcel/*`) | 9 route paths collide today, including `/home`, `/profile`, `/wallet`, `/notifications`, `/search` |
| D5 | Riverpod 3 is the target; taxi's 12 `StateNotifier`s are rewritten | Only one version can resolve; food already uses the 3.x idiom in 26 files |
| D6 | `ApiClient` from food wins; it becomes multi-host capable | 354 lines with refresh, typed `Failure`s, envelope unwrap, and cache vs. taxi's 40-line wrapper |
| D7 | Theme moves to `ThemeExtension` + per-module accent; **the mutable `AppColors.primary` static is removed** | It is the only reason the whole `MaterialApp` has to rebuild on a colour change, and it is incompatible with taxi's 55 `const` uses |
| D8 | One Socket.IO **gateway**, N connections behind it | Lets the app run two backends now and one later without touching call sites |
| D9 | One `PushMessage` envelope + per-module resolvers | Two parsers today, both hardcoding their own `type` strings and route shapes |
| D10 | Localisation is **out of scope** for the merge, but the merged tree is laid out so it can start immediately after | 74k lines of hardcoded strings is its own project; blocking the merge on it would stall everything |
| D11 | Deferred/lazy module init via `AppModule.warmUp()`, not eager bootstrap | Today both apps do push init on first frame; the merged app would do maps + sockets + push + Hive + RTDB before the hub renders |

---

## 0.6 What implementation will look like when the backend arrives

For reference, so the phases in [11-execution-runbook.md](11-execution-runbook.md) make sense:

```
Phase 0  Freeze + baseline      no code moves; measure size/startup, tag both repos
Phase 1  Prune                  delete 14 dead dependencies, delete unused files
Phase 2  Taxi forward-migration  IN THE TAXI REPO: Riverpod 3, go_router 17,
                                 Firebase 4, local-notifications 22. Ship it standalone.
Phase 3  Skeleton               new tree + AppModule contract + hub, food only
Phase 4  Platform unification   core/ + design_system/ ; food refactored onto it
Phase 5  Taxi module import      taxi → modules/taxi, namespaced routes
Phase 6  Parcel + rental        split out of taxi's delivery/ and rental/
Phase 7  Shared collapse        profile, wallet, address, notifications, support,
                                 activity, search  ← NEEDS MERGED BACKEND
Phase 8  Perf + size            deferred init, asset pass, AAB
Phase 9  Localisation           separate project
```

**Phase 2 is the one people skip and regret.** Migrating taxi to the newer packages *while it is still a standalone app that you can run and test* is dramatically cheaper than debugging a Riverpod 3 migration and a merge at the same time, inside a tree that does not compile.
