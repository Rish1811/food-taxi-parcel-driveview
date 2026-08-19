# Chapter 6 — Shared Components

The twelve items in the brief: Profile, Wallet, Address, Support, Notification, Payment, Language, Offers, Referral, Settings, Theme — plus Session, which neither app has properly and the super app cannot work without.

For each: what exists on both sides, what the merged design is, and what it depends on.

---

## 6.0 The pattern every shared feature follows

A shared feature owns the **shell**; modules **contribute** the content.

```
shared/<feature>/
├── data/            one repository, one DTO, talking to one endpoint
├── application/     one controller holding the merged state
└── presentation/    the shell screen + generic widgets
                     ↑
                     modules contribute via the AppModule contract:
                       profileSections()  activitySources()
                       searchSources()    walletHistorySources()
```

Why contribution rather than a big screen with `if (isFoodEnabled)` blocks: adding a fifth module (bus, pooling — both already in the taxi API) must not require editing the profile screen, the wallet screen, the activity screen, and the search screen. It should require writing one module file.

---

## 6.1 Profile

### Today

| | Food | Taxi |
|---|---|---|
| Screen | `presentation/profile/profile_screen.dart` — **1,974 lines** | `features/profile/presentation/profile_screen.dart` — 280 lines |
| Edit | `edit_profile_screen.dart` — 1,099 lines | `edit_profile_screen.dart` — 176 lines |
| Model | `UserModel` 133 lines: name, email, phone, countryCode, avatarUrl, gender, DOB, anniversary, referralCode, referredBy, referralCount, isVerified, isActive, role, walletBalance | `UserModel` 69 lines: name, phone, email, gender, **currentRideId**, profileImage, referralCode, referralCount |
| Endpoint | `GET/PATCH /food/user/profile`, `POST /food/user/profile/profile-image` | `GET/PATCH /users/me`, `POST /users/profile-image` (accepts a `dataUrl`) |
| Delete account | **none** | `delete_account_screen.dart` 104 → `POST /users/me/delete-request` |
| Emergency contacts | none | `emergency_contacts_screen.dart` 123, Hive-backed |

Two observations that matter more than the line counts:

- **Food has no delete-account flow.** Google Play requires an in-app account-deletion path for apps with accounts. Taxi's screen is not optional nice-to-have; it is a store requirement, and it must move to `shared/profile`.
- **Taxi's `currentRideId` on the user object** is a module concern leaking into identity. In the merged model it belongs to taxi's active-job state, fed into `shared/activity/active_jobs_controller`.

### Merged design

```dart
// shared/profile/data/user_dto.dart — identity only. No module fields.
class UserDto {
  final String id, name, email, countryCode;
  final String? phone, avatarUrl, dateOfBirth, anniversary;
  final String gender, role;
  final bool isVerified, isActive;
  // NOT here: walletBalance (→ wallet), currentRideId (→ taxi),
  //           referralCode/Count (→ referral)
}
```

```dart
// the contribution type
class ProfileSection {
  final ModuleId? module;       // null = shared section
  final String title;
  final IconData icon;
  final int order;
  final List<ProfileEntry> entries;
  final bool Function(FeatureFlags) visible;
}
```

Assembled screen:

```
┌─ header ──────────────────  avatar · name · phone · verified badge   [shared]
├─ Account ─────────────────  Edit profile · Addresses · Payment methods  [shared]
├─ Wallet ──────────────────  balance + "Add money"                    [shared]
├─ Food ────────────────────  Favourites · Food orders · Cashback     [FoodModule]
├─ Rides ───────────────────  Ride history · Emergency contacts · Safety [TaxiModule]
├─ Parcel ──────────────────  Parcel history                         [ParcelModule]
├─ Rewards ─────────────────  Referral · Offers · Subscription         [shared]
├─ Support ─────────────────  Help · Tickets · SOS                     [shared]
├─ Settings ────────────────  Theme · Language · Notifications · Security [shared]
└─ Legal / Account ─────────  About · Privacy · Terms · Delete account · Log out [shared]
```

The 1,974-line food screen becomes roughly 250 lines of shell plus a `profileSections()` implementation in each module. **This is the single clearest demonstration of the architecture paying for itself.**

### Depends on

**B1** (one users collection or two). If two, `UserDto` becomes a composite: one identity plus per-module profile fragments joined by phone number, and `edit_profile` has to write to two endpoints — an ugly but survivable transitional design.

---

## 6.2 Wallet

Detail in [Ch. 14](09-maps-search-wallet-activity.md). Summary here because it is the most dangerous item in this chapter.

| | Food | Taxi |
|---|---|---|
| Model | `wallet_model.dart` **378 lines** — balance, cashback ledger, refund history, cashback settings | `wallet_transaction_model.dart` 32 lines |
| Screen | `wallet_screen.dart` 926 lines | `wallet_screen.dart` 128 + `topup_sheet.dart` 113 |
| Top-up | **none** | Razorpay order+verify, PhonePe order+status, transfer, transfer-to-driver |
| Endpoints | `/food/user/wallet`, `/food/user/cashback`, `/food/user/refunds`, `/food/admin/cashback-settings/public` | `/users/wallet`, `/users/wallet/topup`, `/users/wallet/transfer`, `/users/wallet/razorpay/*`, `/users/wallet/phonepe/*` |

Food has the better **display** and no way to add money. Taxi has the better **money-in** and a thin display. Merged: food's screen, taxi's top-up sheet, one balance.

**The hard rule:** never sum two balances. See [Ch. 14](09-maps-search-wallet-activity.md) for why and what to do instead. **Depends on B6.**

---

## 6.3 Address

| | Food | Taxi |
|---|---|---|
| Editor | `add_address_screen.dart` **1,436 lines** — structured fields, map pin, label, save | `delivery_address_screen.dart` 1,165 (parcel-specific) + `saved_places_screen.dart` 147 |
| Map picker | **none** (the editor embeds its own) | `map_picker_screen.dart` 254 — reusable, `?type=pickup\|drop` |
| Store | **server**: `GET/POST/PATCH/DELETE /food/user/addresses` | **Hive box**, device-local. `savedAddresses` |
| Model | `address_model.dart` 109 | `saved_address_model.dart` 37 |
| Geocode | Google REST, structured (building/street/area/city/state/pincode) | `geocoding` plugin, single string |

The conflict is not the model — it is **server vs. device**. Taxi's saved places do not sync, do not survive reinstall, and are invisible to the backend (so dispatch cannot pre-fill them). Food's are server-backed.

### Merged design

```dart
class AddressDto {
  final String? id;                 // null = unsaved / one-off
  final double lat, lng;
  final String formatted;
  final String? building, street, area, landmark, city, state, pincode;
  final AddressLabel label;         // home | work | other | custom
  final String? customLabel;
  final bool isDefault;
  final Set<ModuleId> usedBy;       // analytics + smart ordering
}
```

- **One server-backed address book.** Taxi's Hive box becomes a write-through cache, not the source of truth.
- **One editor** (food's, extended with taxi's map picker as a first-class step) and **one picker sheet** used by food checkout, ride pickup/drop, and parcel sender/receiver.
- **Ride pickup/drop are not always saved addresses.** The picker must return an `AddressDto` with `id == null` for one-off destinations without polluting the address book. Food's editor currently always saves; that has to become optional.
- Migration for existing taxi users: on first launch of the merged app, upload the Hive box contents to the server once, then mark the box as migrated. **This is real user data — do not skip it.**

**Depends on B8.**

---

## 6.4 Support

| | Food | Taxi |
|---|---|---|
| Help screen | `help_support_screen.dart` 840 lines | `support_home_screen.dart` 140 |
| Tickets | **none** | `new_ticket_screen.dart` 94, `ticket_detail_screen.dart` 160, `support_ticket_model.dart` 78 → `/support/tickets`, `/support/tickets/my`, `/support/titles` |
| Chat | `chat/` — `chat_screen.dart` 315 + `chat_viewmodel.dart` 255 + `chat_remote_datasource.dart` 71 + `chat_model.dart` 121. **REST history + socket live** (`chat:message`, `chat:typing`), supports peer roles (`ADMIN`, rider, restaurant) | `ride_chat_screen.dart` 455 — **socket only** (`ride:message:send` / `ride:message:new`), ride-scoped |
| Safety | none | `safety_center_screen.dart` 117, `sos_screen.dart` 129 → `/users/sos` |

**Two chat implementations is the substantive problem here.** They differ architecturally, not just cosmetically:

| | Food chat | Taxi ride chat |
|---|---|---|
| History | REST (`GET /food/chat/messages`) | none — socket only, lost on reconnect |
| Live | socket | socket |
| Scope | conversation id, any peer role | ride id, driver only |
| Typing indicator | yes | no |
| Read receipts | yes (`/conversations/:id/read`) | no |

Food's is the better model. Taxi's is missing persistence, which is a real bug: leaving and returning to a ride chat loses the conversation.

### Merged design

```
shared/support/
├── data/
│   ├── ticket_repository.dart        ← taxi's, unchanged
│   ├── chat_repository.dart          ← food's REST + socket
│   └── sos_repository.dart           ← taxi's
├── application/
│   ├── ticket_controller.dart
│   ├── chat_controller.dart          one controller, `ChatContext` discriminator
│   └── sos_controller.dart
└── presentation/
    ├── support_home_screen.dart      food's UI + taxi's ticket entry points
    ├── chat_screen.dart              one screen
    ├── ticket_*_screen.dart          taxi's
    ├── safety_center_screen.dart     taxi's
    └── sos_screen.dart               taxi's, with an optional job reference
```

```dart
sealed class ChatContext {
  const factory ChatContext.job({required ModuleId module, required String jobId,
      required ChatPeer peer}) = JobChat;      // food order, ride, parcel
  const factory ChatContext.support({required String ticketId}) = SupportChat;
}
```

**SOS is app-wide, not ride-only.** Taxi's SOS route takes `?rideId=`; in the merged app it takes an optional `JobRef(module, id)` so a food customer waiting for a delivery rider at 11 pm has the same button. Emergency contacts move with it.

**Depends on B10.**

---

## 6.5 Notifications

| | Food | Taxi |
|---|---|---|
| Inbox | `notifications_screen.dart` 286 + `notification_inbox_viewmodel.dart` 165 → `/food/notifications/inbox` | `notifications_screen.dart` 94 → `/users/notifications` |
| Per-type settings | `profile/viewmodels/notifications_viewmodel.dart` 48 (partial) | `notification_settings_screen.dart` 59 |
| Model | inline in the viewmodel | `notification_model.dart` 31 |
| Android channel | `high_importance_channel` | `ride_updates` |

### Merged design

```dart
class NotificationDto {
  final String id;
  final ModuleId? module;            // ← REQUEST B4
  final String type, title, body;
  final DateTime createdAt;
  final bool read;
  final String? deepLink;            // resolved through the module registry
  final Map<String, dynamic> data;
}
```

- One inbox screen with a module filter chip row (`All · Food · Rides · Parcel · Offers`).
- Notification **settings become a matrix**: per module × per category (order updates, promotions, driver arrival, price drops). Neither app has this; taxi's screen is the closer starting point.
- **Per-module Android channels** (`food_orders`, `ride_updates`, `parcel_updates`, `promotions`) so muting promos doesn't mute "your driver has arrived". See [Ch. 11](08-api-socket-push.md) — this interacts with the manifest's single `default_notification_channel_id`.

**Depends on B4** (module discriminator) and on whether the merged backend exposes one inbox endpoint or two.

---

## 6.6 Payment

| | Food | Taxi |
|---|---|---|
| Gateway | `payment_gateway.dart` **272 lines** | `razorpay_service.dart` 54 lines |
| Controller | `payment_viewmodel.dart` 87 | none |
| End-of-job sheet | order flow embeds it | `ride_completion_payment_sheet.dart` 185 |
| Verify | `POST /food/orders/verify-payment` | `/users/wallet/razorpay/verify`, `/users/bus-bookings/verify`, `/users/pooling/bookings/verify`, `/users/rental-advance/razorpay/verify` |
| PhonePe | none | **4 endpoints, no client code** |
| Razorpay branding | `AppConstants.brandName = 'Suvio'`, `brandLogoUrl` from env — with a comment explaining that without it Razorpay shows the legal entity name | not set |

### Merged design

```dart
class PaymentIntent {
  final ModuleId module;             // attribution for receipts + wallet entries
  final String purpose;              // 'food_order' | 'ride_fare' | 'wallet_topup'
                                     // | 'rental_advance' | 'subscription'
  final int amountPaise;
  final String? jobId;
  final Map<String, dynamic> metadata;
}

abstract interface class PaymentAdapter {
  Future<PaymentResult> pay(PaymentIntent intent);
}
// adapters: RazorpayAdapter · PhonePeAdapter · WalletAdapter · CodAdapter
```

- One `PaymentGateway` (food's), one method-picker sheet, N adapters.
- **`ModuleId` on the intent is not cosmetic** — it is what lets one wallet ledger and one receipt list attribute a charge correctly.
- **Keep food's Razorpay branding config.** The comment in `app_constants.dart` documents a real production problem (checkout showing "SWITCHEATS PRIVATE LIMITED"); the merged app must set brand name and logo, and the brand shown should arguably follow the active module.
- **Decide on PhonePe.** Four backend endpoints exist with zero client code. Either build the adapter or tell the backend team those endpoints are unused.

---

## 6.7 Language

**This is not a merge task.** Measured:

- Food: `l10n.yaml` present, `generated/l10n/app_localizations.dart` (344 lines) + `_en.dart` (120) generated, `flutter_localizations` declared — and `AppLocalizations` referenced in **3 of 212 files**. The other ~51,000 lines are hardcoded English. `AppConstants.languageList` contains exactly one entry (`English`).
- Taxi: `locale_provider.dart` persists a code and declares five languages (`en, hi, ta, te, kn`). **No ARB files. No `localizationsDelegates`. No `supportedLocales`.** `language_screen.dart` (37 lines) changes a value nothing reads.

So the honest position: the merged app inherits a *language picker that does nothing* and *scaffolding wired to almost nothing*.

### Recommendation

Treat localisation as **Phase 9**, after the merge, as its own project. What the merge should do:

1. Keep food's `l10n.yaml` + `generate: true`, and actually register the delegates in `super_app.dart` (food's root currently sets `theme`/`routerConfig` but no `localizationsDelegates` — so even its three localised strings may not be resolving).
2. Wire `localeController` (taxi's, ported to `Notifier`) to `MaterialApp.locale` so the picker is at least functional for the strings that exist.
3. **Do not** ship a language picker offering Hindi/Tamil/Telugu/Kannada when there are no translations — reduce the list to what actually exists, and re-expand it as ARB files land.
4. Add a lint or CI grep for new hardcoded user-facing strings in `shared/` and `design_system/`, so the debt stops growing while the extraction project runs.

Rough sizing for Phase 9: ~74,000 lines to audit, realistically 3,000–5,000 distinct user-facing strings. That is months, not weeks, and it is why it must not gate the merge.

---

## 6.8 Offers, coupons and promos

| | Food | Taxi |
|---|---|---|
| Home banners | `promo_banner_model.dart` 82, `promo_banner_carousel.dart` 167, `home_header_banner.dart` 320, `exclusive_offers_banner.dart` 281 → `/food/hero-banners/*`, `/food/top-banners/public` | `promo_banner.dart` 77 → `/users/banners` |
| Coupon apply | `coupon_sheet.dart` 332 + `coupons_viewmodel.dart` 57 → `/food/restaurant/offers` | `promo_screen.dart` 114 + `promo_repository.dart` 20 → `/promos/validate`, `/promos/available` |
| All offers | `all_offers_screen.dart` 96 | — |

Note these are **two different concepts** wearing similar names:

- A **banner** is a merchandising slot on a home screen. Module-specific by nature — a food banner on the ride screen is noise. **Keep per module**, rename food's `PromoBannerModel` → `HomeBannerDto`.
- A **coupon** is a discount applied to a transaction. Should be cross-module: "₹50 off your first ride" and "20 % off your food order" belong in one wallet-of-offers.

### Merged design

```
shared/offers/
├── data/  coupon_repository.dart  ·  coupon_dto.dart
├── application/  coupon_controller.dart  (validate against a PaymentIntent)
└── presentation/  offers_screen.dart  ·  coupon_sheet.dart
```

```dart
class CouponDto {
  final String code, title, description;
  final Set<ModuleId> applicableTo;    // ← the key field
  final DiscountType type;             // flat | percent | cashback | freeDelivery
  final num value;
  final num? minOrderValue, maxDiscount;
  final DateTime? validUntil;
  final int? usesLeft;
}
```

The coupon sheet takes a `PaymentIntent` and shows only coupons whose `applicableTo` contains `intent.module` and whose constraints the intent satisfies. Food's sheet UI (332 lines, the better one) generalises with a parameter change.

**Depends on B9.** If the backend keeps two coupon engines, the client can still present one sheet — it just fans out to two validators and the "applicable to" set is inferred from which engine returned it. Workable, but it makes cross-module offers impossible, which is one of the main commercial reasons to build a super app.

---

## 6.9 Referral

| | Food | Taxi |
|---|---|---|
| Screens | `referral/` — 7 files, ~1,146 lines: `referral_screen` 442, `referral_ticket_result_screen` 213, `referral_ticket_card` 196, `rotating_ticket_border` 110, `fire_particle_share_button` 86, `ticket_clipper` 69, `refer_earn_background` 25. Plus a dedicated audio cue | `rewards_screen.dart` 168 |
| Endpoints | `/food/user/referrals/stats`, `/food/user/referrals/details` | `/common/referrals/translation`, `/common/referrals/settings` |
| Model | fields on `UserModel` (`referralCode`, `referredBy`, `referralCount`) | fields on `UserModel` (`referralCode`, `referralCount`) |

Food's implementation is dramatically richer — it is a designed feature with animation and sound. Taxi's is a list.

### Merged design

Food's UI wins essentially unchanged, moved to `shared/referral/`. Two things to settle:

- **One referral code per user, not one per module.** Both apps already put the code on the user object, so this is mostly a backend consolidation.
- **Attribution across modules.** If someone is referred and their first action is a ride, the reward rule may differ from a food-first referral. That is a product decision the client just needs a field for (`CouponDto.applicableTo` already covers the reward side).

Taxi's `/common/referrals/translation` endpoint suggests the referral copy is server-driven there — worth keeping, since it means marketing can change the pitch without a release.

---

## 6.10 Settings

| | Food | Taxi |
|---|---|---|
| Settings hub | none — entries live inside the 1,974-line profile screen | `settings_screen.dart` 93 |
| Theme | mode provider 43 + colour picker 73 | mode provider 41 + `theme_screen.dart` 38 |
| Language | none | `language_screen.dart` 37 |
| Security | none | `security_screen.dart` 58 |
| About | `about_screen.dart` **880** (CMS-driven) | `about_screen.dart` 85 |
| Legal | `privacy_policy_screen.dart` 609 + `terms_conditions_screen.dart` 704 — **hardcoded text** | `static_content_screen.dart` 36 with `privacyPolicyBody` / `termsBody` constants |
| Notif. settings | partial (48-line viewmodel) | `notification_settings_screen.dart` 59 |

### Merged design

Taxi's settings hub structure + food's About + one CMS-backed static-content screen:

```
shared/settings/presentation/
├── settings_screen.dart          hub  ← taxi's
├── theme_screen.dart             mode + module accent + colour picker  ← merged
├── language_screen.dart          ← taxi's, honest about what's translated
├── security_screen.dart          ← taxi's
├── about_screen.dart             ← food's 880-line CMS version
└── static_content_screen.dart    privacy · terms · refund · FAQ, all by key
```

**1,313 lines of legal copy are currently compiled into food's binary.** Food already has `ApiPaths.cmsPage(key)` → `/food/pages/:key` and a `WebViewScreen`. Moving privacy and terms to CMS deletes 1,313 lines, removes the need for an app release to change legal text, and shrinks the binary. Do it.

---

## 6.11 Theme — and killing the mutable statics

This is the most technically constrained item in the chapter.

### Today

| | Food | Taxi |
|---|---|---|
| Colours | `AppColors` — **`static Color primary` is MUTABLE**, deliberately, so `ThemeColorNotifier` can reassign it. 1,125 read sites | `AppColors` — **`static const`**. 205 read sites, **55 inside `const` expressions** |
| Brand | orange `0xFFFF7A00` | orange `0xFFFF5C2B` |
| Theme builder | `buildLightTheme()` / `buildDarkTheme()`, rebuilt on every call | `AppTheme.light` / `AppTheme.dark` getters |
| Font | Poppins via `google_fonts`, applied across every M3 text role (with a good comment explaining why a sparse `TextTheme` breaks) + bundled `ManropeVariable` | `'Roboto'` string |
| Mode provider | `theme_provider.dart` 43 | `theme_provider.dart` 41 — **both exist, different persistence keys** |
| Colour picker | 6 presets (orange/green/blue/red/purple/pink) | none |
| Extras taxi has | `dividerTheme`, `bottomSheetTheme`, `snackBarTheme`, `splashFactory`, `surfaceTintColor: transparent` | |
| Extras food has | `cardTheme` with a spec-matched shadow, `inputDecorationTheme` at radius 18 vs taxi's 16, button radius 24 vs 16 | |

**The incompatibility is exact.** If `AppColors.primary` stays mutable, all 55 of taxi's `const` uses fail to compile. If it becomes `const`, food's colour picker stops working. There is no version that satisfies both without editing code.

Beyond that, the mutable-static approach has a real cost even on its own terms: changing the colour rebuilds `MaterialApp`, therefore the entire widget tree. In a super app with a live map and an active socket, that is a visible hitch.

### Merged design

**Three layers.**

**1. Semantic tokens** — no brand colours, just roles:

```dart
// design_system/tokens/color_tokens.dart
class ColorTokens {
  static const surfaceLight = Color(0xFFFFFFFF);
  static const backgroundLight = Color(0xFFF7F8FA);   // food's
  static const backgroundDark  = Color(0xFF09121D);   // taxi's (better contrast)
  static const textPrimaryLight = Color(0xFF0F172A);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  // …no `primary` here. Primary is per-module.
}
```

**2. Per-module accent:**

```dart
// design_system/tokens/module_accent.dart
enum ModuleAccent {
  hub   (Color(0xFFFF7A00), Color(0xFFFF8A1D)),
  food  (Color(0xFFFF7A00), Color(0xFFFF8A1D)),   // Suvio
  taxi  (Color(0xFFFF5C2B), Color(0xFFE04313)),   // UdanX
  parcel(Color(0xFFF59E0B), Color(0xFFD97706)),
  rental(Color(0xFF3B82F6), Color(0xFF2563EB));
  const ModuleAccent(this.primary, this.primaryVariant);
  final Color primary, primaryVariant;
}
```

**3. A `ThemeExtension` carrying the resolved palette:**

```dart
// design_system/theme/app_theme_extension.dart
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary, primaryVariant, surface, background,
              textPrimary, textSecondary, border, card,
              success, warning, error;
  // copyWith + lerp
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
```

Then a module's route subtree re-accents itself without touching the root:

```dart
class ModuleTheme extends StatelessWidget {
  final ModuleAccent accent;
  final Widget child;
  @override
  Widget build(BuildContext c) => Theme(
    data: Theme.of(c).withAccent(accent),   // swaps colorScheme.primary + AppPalette
    child: child,
  );
}
```

### Migration path — 1,330 call sites, done safely

You cannot hand-edit 1,330 references. The staged approach:

**Stage 1 — make the shim.** Keep `AppColors` as a deprecated façade whose members read from a single global palette holder. Every existing `AppColors.primary` keeps compiling. Taxi's 55 `const` uses are the only forced edits: drop `const` from those expressions (mechanical, compiler-guided — remove `const`, the analyzer tells you exactly where).

**Stage 2 — introduce `context.palette`** and use it in all *new* code, including everything in `design_system/`.

**Stage 3 — migrate by folder**, in this order: `design_system/` → `shared/` → `modules/taxi|parcel|rental` (205 sites) → `modules/food` (1,125 sites). Food last, because it is the biggest and the least urgent; a deprecated-but-working façade is fine there for a long time.

**Stage 4 — delete `AppColors`.** Mark it `@Deprecated` in Stage 1 so the analyser counts down for you.

**The one thing not to do** is attempt Stages 1–4 during the tree merge. Do Stage 1 + the 55 `const` edits as part of Phase 4, and let Stages 2–4 run as background cleanup across later phases.

### Also reconcile

- **Two theme-mode providers with different persistence keys.** Pick one key; on first launch of the merged app, read both and prefer the food one (larger user base) so nobody's dark mode resets.
- **Two fonts.** Food's `_poppinsTextTheme` comment is worth reading before deciding — it documents that passing a sparse `TextTheme` to `GoogleFonts.poppinsTextTheme` leaves most M3 roles null and silently falls back to the platform font. Whatever font wins, apply it the way food does.
- **Radius and button-height differ** (food 18/24/56, taxi 16/16/56). Tokenise (`radius.sm/md/lg`) and pick one set; this is a product call, and it is the visible "does the super app feel like one app" question.

---

## 6.12 Session — the missing shared component

Not in the brief, but the super app does not work without it, and each app has half of it.

| Capability | Food | Taxi |
|---|---|---|
| Splash → route decision | `splash_screen.dart` 247 → food home | `splash_screen.dart` 61 → `/home` |
| Session restore | `AuthRepositoryImpl.restoreSession()` | `AuthController` + `GET /users/me` |
| Session-expired signal | `SessionExpiredNotifier` in `di/network_providers.dart` | `DioClient.onUnauthorized` callback |
| Session-expired screen | **none** | `session_expired_screen.dart` 26 |
| Forced logout | reactive listener in `food_user_application.dart` | `force_logout_screen.dart` 28 |
| Force update | **none** | `force_update_screen.dart` 38 |
| Maintenance mode | **none** | `maintenance_screen.dart` 19 |
| No internet | `offline_banner.dart` 42 (banner) | `no_internet_screen.dart` 41 (full screen) |
| GPS off / location denied | none | 2 screens |

### Merged design

```dart
// shared/session/application/session_state.dart
sealed class SessionState {
  const factory SessionState.booting()                       = Booting;
  const factory SessionState.onboarding()                    = Onboarding;
  const factory SessionState.guest()                         = Guest;
  const factory SessionState.authenticated(UserDto user)     = Authenticated;
  const factory SessionState.expired()                       = Expired;
  const factory SessionState.forcedOut(String reason)         = ForcedOut;
  const factory SessionState.updateRequired(String url)       = UpdateRequired;
  const factory SessionState.maintenance(String? message)     = Maintenance;
}
```

`SessionController` is the single source of truth. The router's top-level `redirect` reads it — which is how you get "one place decides what the user can see", instead of today's arrangement where a 401 interceptor, a splash screen, an auth listener, and a `NoDriverWatcher` all independently push routes.

**Guest mode matters more in a super app.** Food supports browsing restaurants unauthenticated (its login route takes a `?from=` so it can return you). Taxi requires login before anything. The merged app should let a user browse food *and* see ride fare estimates as a guest, and only demand auth at the point of committing an order or booking. That is a routing/redirect design detail — see [Ch. 7 §7.7](06-routing-and-navigation.md).

---

## 6.13 Summary — line impact of the shared collapse

| Component | Food lines | Taxi lines | Merged (est.) | Saved |
|---|---|---|---|---|
| Profile + edit | 3,073 | 456 | ~1,400 | ~2,100 |
| Wallet | 1,494 | 320 | ~1,200 | ~600 |
| Address | 1,672 | 518 | ~1,600 | ~590 |
| Support + chat | 1,766 | 1,248 | ~1,900 | ~1,100 |
| Notifications | 451 | 207 | ~450 | ~200 |
| Payment | 359 | 54 | ~450 | — (grows: adapters + PhonePe) |
| Offers/coupons | 485 | 203 | ~500 | ~190 |
| Referral | 1,146 | 168 | ~1,150 | ~160 |
| Settings + legal | 2,193 | 260 | ~700 | ~1,750 |
| Theme | 439 | 374 | ~600 | ~210 |
| Session | ~50 | 405 | ~600 | — (grows: real coverage) |
| **Total** | **~13,100** | **~4,200** | **~10,550** | **~6,750** |

~6,750 lines removed from the shared layer, and the result covers more cases than either app does today (delete account, force update, maintenance, per-module notification settings, cross-module coupons, server-backed saved places, CMS legal text).

**All of it is gated on B1, B6, B8, B9, B10.** That is why Phase 7 sits after the backend hand-off in the runbook.
