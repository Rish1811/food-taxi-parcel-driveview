# Chapters 3 & 4 — File Migration Map and Deletion List

Every one of the 385 Dart files, resolved. Paths are relative to each app's `lib/`.

**Legend**

| Code | Meaning |
|---|---|
| **MOVE** | Relocate, fix imports, no logic change |
| **MOVE+NS** | Relocate and rename to a module-qualified name (collision resolution) |
| **PORT** | Relocate **and** migrate API usage (Riverpod 3, go_router 17, notifications 22, …) |
| **MERGE** | Two files become one; winner named |
| **REBUILD** | Discard the implementation, keep the behaviour spec |
| **SPLIT** | One file becomes several |
| **DELETE** | Gone; nothing to preserve |
| **HOLD** | Blocked on a backend answer (B1–B10 in [README §0.4](README.md)) |

`F:` = food (`Food_user/flutter-food-user-application/lib/`) · `T:` = taxi (`flutter_taxi_user/lib/`)

---

## 3.1 Entry point and app root

| From | Lines | Action | To |
|---|---|---|---|
| `F: main.dart` | 24 | MERGE (host) | `main.dart` — trimmed to ~20 lines |
| `T: main.dart` | 86 | MERGE (fold in) | `bootstrap.dart` — Hive/secure-storage init + `ProviderScope` overrides pattern |
| `F: src/food_user_application.dart` | 120 | REBUILD | `app/super_app.dart` — keeps `ScreenUtilInit`, push wiring, auth listener; loses the food-specific deep-link handler (→ `PushRouter`) |
| `T: app/app.dart` | 38 | MERGE | `app/super_app.dart` — keeps `_AppScrollBehavior` (overscroll glow removal) |
| `T: app/router.dart` | 217 | SPLIT | `modules/{taxi,parcel,rental}/*_routes.dart` + `shared/*` routes; see [Ch. 7](06-routing-and-navigation.md) |
| `F: src/presentation/navigation/app_router.dart` | 364 | SPLIT | `app/di/app_providers.dart` (router provider) + `modules/food/food_routes.dart` + shared routes |
| `F: src/presentation/navigation/route_names.dart` | 35 | REBUILD | `app/routes.dart` + per-module `*Routes` classes — all namespaced |
| `F: src/presentation/navigation/back_navigation.dart` | 22 | MOVE | `core/utils/back_navigation.dart` |
| `T: core/navigation/navigator_key.dart` | 3 | MERGE | `app/di/app_providers.dart` — one `rootNavigatorKey` (currently declared in **both**) |

---

## 3.2 → `core/` (platform layer)

### `core/config/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/core/constants/app_constants.dart` | 90 | SPLIT | `core/config/env.dart` + `design_system/tokens/*` | Env values → `env.dart`; `LocaleLanguageList` → `shared/settings` |
| `T: core/constants/app_constants.dart` | 84 | SPLIT | `core/config/env.dart` + `design_system/tokens/typography.dart` + `modules/taxi/taxi_constants.dart` | **Six `TextStyle` constants live in this file** — they belong in the design system. `otpLength`, `phoneLength`, `defaultZoomLevel`, `otpResendCooldown` → taxi/shared constants |
| `F: src/core/config/api_config.dart` | 102 | SPLIT | `core/config/backend_endpoint.dart` (`ApiConfig`, `resolveMedia`) + `modules/food/api/food_endpoints.dart` (`ApiPaths`) | `resolveMedia` is used by models to absolutise `/uploads/…` paths — it must stay in `core` |
| `T: core/constants/api_constants.dart` | 110 | SPLIT ×4 | `modules/taxi/api/taxi_endpoints.dart`, `modules/parcel/api/parcel_endpoints.dart`, `modules/rental/api/rental_endpoints.dart`, `shared/*/api/*_endpoints.dart` | Split detail in §3.9 |
| `T: core/constants/storage_keys.dart` | 14 | MOVE | `core/storage/storage_keys.dart` | |
| — | new | CREATE | `core/config/flavors.dart`, `core/config/feature_flags.dart` | |

### `core/network/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/core/network/api_client.dart` | 354 | PORT | `core/network/api_client.dart` + `core/network/interceptors/cache_interceptor.dart` | **Winner.** Changes: (1) `baseUrl` becomes a constructor param instead of reading `ApiConfig.baseUrl`; (2) `_CacheInterceptor` extracted and given a `CacheStore` instead of touching `SharedPreferences` directly; (3) refresh path becomes pluggable so a `bearerOnly` endpoint can opt out |
| `F: src/core/network/api_response.dart` | 8 | MOVE | `core/network/api_response.dart` | |
| `F: src/core/error/failures.dart` | 46 | MOVE | `core/error/failure.dart` | |
| `T: core/network/api_client.dart` | 40 | **DELETE** | — | Fully superseded. All 20+ taxi repositories must be rewritten against the new client |
| `T: core/network/dio_client.dart` | 40 | **DELETE** | — | Superseded |
| `T: core/network/api_exception.dart` | 44 | MERGE → DELETE | `core/error/error_mapper.dart` | Keep the `fromDioError` mapping detail, discard the class |
| — | new | CREATE | `core/network/api_client_registry.dart` | `Provider.family<ApiClient, String>` keyed by `endpointId` |

**This is the single largest mechanical task in the migration.** Every taxi repository currently does `await api.get(path)` returning `dynamic` and hand-casts. Against food's client they become `await api.get<Map<String,dynamic>>(path)` with typed `Failure`s. Affected: `auth_repository` (99), `home_repository` (80), `ride_repository` (111), `delivery_repository` (107), `rental_repository` (76), `wallet_repository` (47), `support_repository` (54), `subscription_repository` (25), `notifications_repository` (23), `promo_repository` (20) — **10 files, ~642 lines**.

### `core/realtime/`

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/platform/realtime/socket_service.dart` | 174 | REBUILD | `core/realtime/socket_channel.dart` (transport, reconnect, room replay) + `modules/food/application/food_socket_binding.dart` (the food event set + `OrderSocketMessage` parsing) |
| `T: core/services/socket_service.dart` | 125 | REBUILD | `core/realtime/socket_channel.dart` — contributes handler replay + `addConnectionListener` + dispose-before-replace |
| `T: core/services/socket_events.dart` | 25 | MOVE+NS | `modules/taxi/api/taxi_socket_events.dart` |
| — | new | CREATE | `core/realtime/socket_gateway.dart`, `socket_binding.dart`, `socket_lifecycle.dart` |
| `F: src/di/socket_providers.dart` | 50 | REBUILD | `core/realtime/socket_lifecycle.dart` — the login/logout sync logic generalises to N channels |

### `core/push/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/platform/notifications/push_service.dart` | 457 | PORT | `core/push/push_service.dart` + `push_background_handler.dart` + `push_message.dart` | Remove `PushDeepLink` (food-specific `isOrderEvent` prefixes) → replaced by `PushMessage` + `resolvePush()`. Remove the direct `AccountRemoteDataSource` dependency → inject a `PushTokenSink` |
| `T: core/services/notification_service.dart` | 98 | **DELETE** | — | Will not compile against `flutter_local_notifications` 22 (positional → named args). Two behaviours survive: the trip-started / ride-ended **audio cue** → `TaxiModule.resolvePush()` side-effect; iOS `DarwinInitializationSettings` → `push_channels.dart` (food's init omits iOS entirely) |
| `F: src/di/push_providers.dart` | 10 | MOVE | `core/push/push_providers.dart` |
| — | new | CREATE | `core/push/push_router.dart`, `core/push/push_channels.dart` |

**Both apps register a top-level `firebaseMessagingBackgroundHandler`.** They collide by name (both are `@pragma('vm:entry-point')` top-level functions). One survives.

### `core/storage/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/core/storage/token_storage.dart` | 64 | MERGE (host) | `core/storage/token_storage.dart` | Keeps the memory-cached access+refresh pair and iOS `first_unlock` accessibility. **Adds taxi's `AndroidOptions(encryptedSharedPreferences: true)`** — food omits it, taxi sets it |
| `T: core/storage/secure_storage_service.dart` | 19 | MERGE → DELETE | — | Contributes the Android option and `clearAll()` |
| `T: core/storage/local_storage_service.dart` | 19 | PORT | `core/storage/box_store.dart` | Boxes open **lazily on first access**, not all five at boot |
| — | new | CREATE | `core/storage/kv_store.dart` (SharedPreferences facade), `core/storage/cache_store.dart` |

### `core/location/`, `core/maps/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/platform/location/location_service.dart` | 281 | SPLIT | `core/location/location_service.dart` + `core/location/geocoding_service.dart` + `core/location/place_search_service.dart` | Keeps `UserLocationResult` (structured building/street/area/city/state/pincode) and `PlaceSuggestion`. Uses Google Geocoding **REST** via Dio |
| `T: core/services/location_service.dart` | 137 | MERGE → DELETE | `core/location/geocode_cache.dart` | **Keep the caching layer**: ~55 m grid memory cache, <50 m movement skip, 3 s throttle. Discard its `geocoding`-plugin call path in favour of food's REST call, so both modules resolve addresses identically |
| `T: core/theme/app_map_style.dart` | 157 | MOVE | `core/maps/map_style.dart` | |
| `F: src/core/utils/map_styles.dart` | 26 | MERGE → DELETE | `core/maps/map_style.dart` | Taxi's is the richer style |
| `T: core/utils/marker_icon_loader.dart` | 74 | MERGE | `core/maps/marker_factory.dart` | |
| `T: core/utils/vehicle_marker_icons.dart` | 89 | MERGE | `core/maps/marker_factory.dart` | |
| `T: core/utils/route_marker_helper.dart` | 107 | MERGE | `core/maps/marker_factory.dart` | |
| `T: core/utils/polyline_decoder.dart` | 52 | MOVE | `core/maps/polyline_service.dart` | |
| `T: core/services/route_polyline_service.dart` | 118 | MERGE | `core/maps/polyline_service.dart` | |
| — | new | CREATE | `core/maps/map_camera.dart`, `core/maps/live_track_controller.dart` | Extracted from food's `live_tracking_map.dart` (894) and taxi's `ride_tracking_screen.dart` (658) |

**Note on `flutter_polyline_points`:** food declares it and uses it in 2 files; taxi hand-rolls `polyline_decoder.dart` (52 lines). Pick one. Recommendation: keep taxi's decoder (no dependency, no API-key round trip) and use `flutter_polyline_points` only where a Directions API call is actually being made.

### `core/payment/`, `core/permissions/`, `core/connectivity/`, `core/audio/`, `core/speech/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/platform/payment/payment_gateway.dart` | 272 | PORT | `core/payment/payment_gateway.dart` + `adapters/razorpay_adapter.dart` | Winner. Add `PaymentIntent` carrying `moduleId` so receipts and wallet entries are attributable |
| `T: core/services/razorpay_service.dart` | 54 | **DELETE** | — | Superseded |
| — | new | CREATE | `core/payment/adapters/phonepe_adapter.dart` | Taxi's backend exposes 4 PhonePe endpoints (`walletPhonepeOrder`, `walletPhonepeStatus`, `rentalAdvancePhonepe*`) with **no client code at all**. Flag for product: is PhonePe in scope? |
| `F: src/platform/network/network_status_provider.dart` | 58 | REBUILD | `core/connectivity/connectivity_service.dart` | Replaces a 5-second `InternetAddress.lookup` timer with `connectivity_plus` (already in taxi's pubspec) + one reachability probe on change |
| `F: src/platform/speech/speech_service.dart` | 128 | MOVE | `core/speech/speech_service.dart` | Feeds unified search ([Ch. 13](09-maps-search-wallet-activity.md)) |
| `T: core/services/audio_service.dart` | 42 | MERGE | `core/audio/audio_service.dart` | |
| `F: src/core/utils/referral_audio_player.dart` | 75 | MERGE → DELETE | `core/audio/audio_service.dart` | |
| `F: src/core/utils/refresh_audio_player.dart` | 62 | MERGE → DELETE | `core/audio/audio_service.dart` | Three near-identical players → one service |
| — | new | CREATE | `core/permissions/permission_service.dart` | Today `permission_handler` is called from `push_service`, `location_service`, `food_user_application`, and taxi's two permission screens |

### `core/utils/`

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/core/utils/haptics.dart` | 26 | MOVE | `core/utils/haptics.dart` |
| `F: src/core/utils/localizations.dart` | 6 | MOVE | `core/utils/l10n_ext.dart` |
| `T: core/utils/formatters.dart` | 39 | MERGE | `core/utils/formatters.dart` + `money.dart` + `duration.dart` |
| `T: core/utils/validators.dart` | 34 | MOVE | `core/utils/validators.dart` |
| `T: core/utils/snackbar_utils.dart` | 48 | MERGE → DELETE | `design_system/components/feedback/` |
| `F: src/domain/service/deep_link_service.dart` | 115 | PORT | `core/utils/deep_link_parser.dart` | Currently only knows food paths; must resolve through the module registry |

---

## 3.3 → `design_system/`

### Tokens and theme

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/presentation/branding/app_colors.dart` | 52 | REBUILD | `design_system/tokens/color_tokens.dart` | **The mutable `static Color primary` / `primaryButton` are removed.** 1,125 read sites migrate to `context.palette.primary` |
| `T: core/theme/app_colors.dart` | 69 | MERGE → DELETE | `design_system/tokens/color_tokens.dart` + `module_accent.dart` | Its six category colours (`rideCategory`, `bikeCategory`, `autoCategory`, `parcelCategory`, `rentalsCategory`, `outstationCategory`) become `ModuleAccent` values. 205 read sites, **55 of them in `const` expressions** — all 55 must lose `const` |
| `F: src/presentation/branding/app_text_styles.dart` | 57 | MERGE | `design_system/tokens/typography.dart` | |
| `T: core/theme/app_text_styles.dart` | 63 | MERGE → DELETE | `design_system/tokens/typography.dart` | |
| `T: core/constants/app_constants.dart` (6 `TextStyle`s) | — | MERGE | `design_system/tokens/typography.dart` | Font families differ: food Poppins (via `google_fonts`) + bundled `ManropeVariable`; taxi `'Roboto'`. **Pick one** |
| `F: src/presentation/branding/app_theme.dart` | 214 | MERGE (host) | `design_system/theme/app_theme.dart` | Becomes `buildLight(ModuleAccent)` / `buildDark(ModuleAccent)` |
| `T: core/theme/app_theme.dart` | 201 | MERGE → DELETE | `design_system/theme/app_theme.dart` | Contributes `dividerTheme`, `bottomSheetTheme`, `snackBarTheme`, `splashFactory` — all absent from food's |
| `F: src/presentation/branding/theme_provider.dart` | 43 | MERGE | `design_system/theme/theme_controller.dart` | |
| `T: core/providers/theme_provider.dart` | 41 | MERGE → DELETE | `design_system/theme/theme_controller.dart` | **Both declare a theme-mode provider**; two persistence keys must be reconciled or the user's choice resets once |
| `F: src/presentation/branding/theme_color_provider.dart` | 73 | PORT | `design_system/theme/theme_controller.dart` | The 6-colour user picker survives; the mechanism (mutating statics) does not |
| `F: src/presentation/branding/brand_logos.dart` | 23 | MOVE | `design_system/tokens/brand_assets.dart` | |
| — | new | CREATE | `design_system/theme/app_theme_extension.dart`, `tokens/{spacing,radius,elevation,motion}.dart` | Neither app has spacing/radius tokens; magic numbers everywhere |

### Components — the six direct duplicates

| Food | Lines | Taxi | Lines | Winner | Target |
|---|---|---|---|---|---|
| `common_widgets/primary_button.dart` | 51 | `shared/widgets/primary_button.dart` + `secondary_button.dart` | 94 + 44 | **Taxi** (has variants + loading state) | `components/buttons/app_button.dart` |
| `common_widgets/custom_text_field.dart` | 58 | `shared/widgets/app_text_field.dart` | 61 | **Taxi** (marginally) | `components/inputs/app_text_field.dart` |
| `common_widgets/empty_state_widget.dart` | 58 | `shared/widgets/empty_state.dart` | 59 | **Merge** | `components/media/empty_state.dart` |
| `common_widgets/skeleton_loading.dart` | 360 | `shared/widgets/shimmer_widgets.dart` + `loading_widget.dart` | 80 + 34 | **Food** (far richer) | `components/skeletons/*` |
| `common_widgets/app_snackbar.dart` + `top_toast.dart` | 146 + 221 | `core/utils/snackbar_utils.dart` | 48 | **Food** | `components/feedback/app_feedback.dart` |
| `main/widgets/custom_bottom_nav.dart` | 136 | `shared/widgets/app_bottom_navigation_bar.dart` | 121 | **Food** (shell-driven, preserves branch state) | `components/nav/app_bottom_nav.dart` |

### Components — food-only (move as-is)

| From | Lines | To |
|---|---|---|
| `common_widgets/smart_image.dart` | 91 | `components/media/smart_image.dart` |
| `common_widgets/offline_banner.dart` | 42 | `components/feedback/offline_banner.dart` |
| `common_widgets/app_refresh_indicator.dart` | 64 | `components/layout/app_refresh_indicator.dart` |
| `common_widgets/exit_confirmation_dialog.dart` | 135 | `components/feedback/exit_confirmation_dialog.dart` |
| `common_widgets/collapsing_header_delegate.dart` | 112 | `components/layout/collapsing_header.dart` |
| `common_widgets/image_pools.dart` | 48 | `components/media/image_pools.dart` |

### Components — taxi-only (move as-is)

| From | Lines | To | Note |
|---|---|---|---|
| `shared/widgets/otp_field.dart` | 57 | `components/inputs/otp_field.dart` | Food's OTP screen hand-rolls its input |
| `shared/widgets/app_search_bar.dart` | 65 | `components/inputs/search_field.dart` | |
| `shared/widgets/custom_app_bar.dart` | 40 | `components/layout/app_bar.dart` | |
| `shared/widgets/custom_bottom_sheet.dart` | 65 | `components/layout/app_bottom_sheet.dart` | |
| `shared/widgets/section_title.dart` | 29 | `components/layout/section_title.dart` | |
| `shared/widgets/profile_tile.dart` | 92 | `components/cards/profile_tile.dart` | |
| `shared/widgets/price_card.dart` | 65 | `components/cards/price_card.dart` | |
| `shared/widgets/map_fab.dart` | 30 | `components/buttons/map_fab.dart` | |
| `shared/widgets/promo_banner.dart` | 77 | `components/cards/promo_banner.dart` | |

### Components — taxi widgets that are actually taxi domain (do **not** put in design system)

| From | Lines | To |
|---|---|---|
| `shared/widgets/driver_card.dart` | 99 | `modules/taxi/presentation/widgets/driver_card.dart` |
| `shared/widgets/vehicle_card.dart` | 97 | `modules/taxi/presentation/widgets/vehicle_card.dart` |
| `shared/widgets/ride_card.dart` | 220 | `shared/activity/presentation/widgets/ride_activity_card.dart` |

That last row matters: `ride_card.dart` and food's `restaurant_hero_card` / order rows all become **activity row renderers** contributed by their module ([Ch. 15](09-maps-search-wallet-activity.md)).

---

## 3.4 → `shared/`

### `shared/session/` — taxi's `misc/` wholesale

| From | Lines | Action | To |
|---|---|---|---|
| `T: features/misc/presentation/force_update_screen.dart` | 38 | PORT | `shared/session/presentation/force_update_screen.dart` |
| `T: features/misc/presentation/maintenance_screen.dart` | 19 | PORT | `shared/session/presentation/maintenance_screen.dart` |
| `T: features/misc/presentation/no_internet_screen.dart` | 41 | PORT | `shared/session/presentation/no_internet_screen.dart` |
| `T: features/misc/presentation/server_error_screen.dart` | 19 | PORT | `shared/session/presentation/server_error_screen.dart` |
| `T: features/misc/presentation/gps_disabled_screen.dart` | 18 | PORT | `shared/session/presentation/gps_disabled_screen.dart` |
| `T: features/misc/presentation/location_permission_denied_screen.dart` | 20 | PORT | `shared/session/presentation/location_denied_screen.dart` |
| `T: features/misc/presentation/session_expired_screen.dart` | 26 | PORT | `shared/session/presentation/session_expired_screen.dart` |
| `T: features/misc/presentation/force_logout_screen.dart` | 28 | PORT | `shared/session/presentation/force_logout_screen.dart` |
| `T: features/misc/presentation/widgets/system_status_view.dart` | 73 | PORT | `shared/session/presentation/widgets/system_status_view.dart` |
| `T: features/splash/presentation/splash_screen.dart` | 61 | MERGE | `shared/session/presentation/splash_screen.dart` |
| `F: src/presentation/splash/splash_screen.dart` | 247 | MERGE → REBUILD | `shared/session/presentation/splash_screen.dart` — must resolve to **hub**, not food home |
| `T: features/onboarding/presentation/onboarding_screen.dart` | 236 | PORT | `shared/session/presentation/onboarding_screen.dart` — copy must cover all services, not just rides |
| `T: features/home/presentation/no_driver_watcher.dart` | 95 | PORT | `shared/session/application/module_event_watcher.dart` — generalise |
| `F: src/di/network_providers.dart` (`SessionExpiredNotifier`) | 28 | MERGE | `shared/session/application/session_controller.dart` |
| — | new | CREATE | `shared/session/application/session_controller.dart`, `session_state.dart` |

### `shared/auth/` — **HOLD on B1/B2**

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/data/datasources/auth_remote_datasource.dart` | 110 | HOLD → MERGE | `shared/auth/data/auth_api.dart` |
| `F: src/data/repository/auth_repository_impl.dart` | 123 | HOLD → MERGE (host) | `shared/auth/data/auth_repository.dart` |
| `F: src/domain/repository/auth_repository.dart` | 43 | HOLD → MERGE | contract folds into the impl |
| `F: src/data/models/auth_session.dart` | 34 | HOLD → MERGE | `shared/auth/data/session_dto.dart` |
| `T: features/auth/data/auth_repository.dart` | 99 | HOLD → MERGE → DELETE | contributes `OtpSendResult` / `OtpVerifyResult` (`exists` flag drives the signup branch — food has no equivalent) |
| `T: features/auth/data/models/user_model.dart` | 69 | HOLD → MERGE → DELETE | `currentRideId` moves to `modules/taxi` |
| `F: src/data/models/user_model.dart` | 133 | HOLD → MERGE (host) | `shared/profile/data/user_dto.dart` |
| `F: src/presentation/auth/viewmodels/auth_viewmodel.dart` | 197 | HOLD → PORT | `shared/auth/application/auth_controller.dart` |
| `T: features/auth/application/auth_controller.dart` | 139 | HOLD → MERGE → DELETE | |
| `T: features/auth/application/auth_state.dart` | 23 | HOLD → MERGE → DELETE | |
| `T: features/auth/application/auth_providers.dart` | 14 | DELETE | |
| `F: src/di/auth_providers.dart` | 17 | MOVE | `shared/auth/application/auth_providers.dart` |
| `F: src/presentation/auth/screens/login_screen.dart` | 769 | MERGE (host) | `shared/auth/presentation/phone_entry_screen.dart` |
| `T: features/auth/presentation/phone_entry_screen.dart` | 300 | MERGE → DELETE | |
| `F: src/presentation/auth/screens/otp_screen.dart` | 428 | MERGE (host) | `shared/auth/presentation/otp_screen.dart` — adopt taxi's `otp_field` widget |
| `T: features/auth/presentation/otp_screen.dart` | 215 | MERGE → DELETE | |
| `F: src/presentation/auth/screens/profile_setup_screen.dart` | 273 | MERGE (host) | `shared/auth/presentation/profile_setup_screen.dart` |
| `T: features/auth/presentation/profile_setup_screen.dart` | 123 | MERGE → DELETE | |
| `T: features/auth/presentation/location_permission_screen.dart` | 73 | PORT | `shared/auth/presentation/location_permission_screen.dart` — food has no equivalent |
| `T: features/auth/presentation/notification_permission_screen.dart` | 72 | PORT | `shared/auth/presentation/notification_permission_screen.dart` — food prompts silently on first frame; taxi's explicit screen is better |
| `T: features/auth/presentation/account_created_screen.dart` | 51 | PORT | `shared/auth/presentation/account_created_screen.dart` |
| `F: src/presentation/auth/widgets/auth_header.dart` | 38 | MOVE | `shared/auth/presentation/widgets/auth_header.dart` |
| `F: src/presentation/auth/widgets/hero_curve_clipper.dart` | 37 | MOVE | `design_system/components/layout/hero_curve_clipper.dart` |

### `shared/profile/`, `shared/settings/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/presentation/profile/profile_screen.dart` | 1,974 | REBUILD | `shared/profile/presentation/profile_screen.dart` | 1,974 lines of a single screen listing food-only entries. Rebuild as shell + `ProfileSection` contributions from each module |
| `T: features/profile/presentation/profile_screen.dart` | 280 | DELETE | — | Its entries become `TaxiModule.profileSections()` |
| `F: src/presentation/profile/screens/edit_profile_screen.dart` | 1,099 | MERGE (host) | `shared/profile/presentation/edit_profile_screen.dart` | |
| `T: features/profile/presentation/edit_profile_screen.dart` | 176 | MERGE → DELETE | — | Contributes the `dataUrl` image-upload path |
| `F: src/data/datasources/account_remote_datasource.dart` | 230 | HOLD → SPLIT | `shared/profile/data/user_repository.dart` + `core/push/push_token_sink.dart` | Currently mixes profile CRUD with FCM token save/remove |
| `T: features/profile/presentation/delete_account_screen.dart` | 104 | PORT | `shared/profile/presentation/delete_account_screen.dart` | Food has no delete-account flow. **Play Store requires one** |
| `T: features/profile/presentation/emergency_contacts_screen.dart` | 123 | PORT | `modules/taxi/presentation/emergency_contacts_screen.dart` | Ride-safety specific; contributed as a profile section |
| `T: features/profile/application/emergency_contacts_provider.dart` | 38 | PORT | `modules/taxi/application/emergency_contacts_controller.dart` | Hive-backed |
| `T: features/profile/data/models/emergency_contact_model.dart` | 29 | MOVE | `modules/taxi/data/models/emergency_contact.dart` | |
| `T: features/profile/presentation/language_screen.dart` | 37 | PORT | `shared/settings/presentation/language_screen.dart` | Currently decorative (no delegates) |
| `T: features/profile/application/locale_provider.dart` | 29 | PORT | `shared/settings/application/locale_controller.dart` | `StateNotifier` → `Notifier` |
| `T: features/profile/presentation/theme_screen.dart` | 38 | MERGE | `shared/settings/presentation/theme_screen.dart` | Merge with food's theme-colour picker |
| `T: features/settings/presentation/settings_screen.dart` | 93 | PORT | `shared/settings/presentation/settings_screen.dart` | |
| `T: features/settings/presentation/security_screen.dart` | 58 | PORT | `shared/settings/presentation/security_screen.dart` | |
| `T: features/settings/presentation/static_content_screen.dart` | 36 | MERGE | `shared/settings/presentation/static_content_screen.dart` | |
| `T: features/settings/presentation/about_screen.dart` | 85 | MERGE → DELETE | — | Food's 880-line CMS-driven About wins |
| `F: src/presentation/about/screens/about_screen.dart` | 880 | MOVE | `shared/settings/presentation/about_screen.dart` | |
| `F: src/presentation/profile/screens/privacy_policy_screen.dart` | 609 | MERGE | `shared/settings/presentation/static_content_screen.dart` | 609 lines of hardcoded policy text → CMS |
| `F: src/presentation/profile/screens/terms_conditions_screen.dart` | 704 | MERGE | `shared/settings/presentation/static_content_screen.dart` | Same. **1,313 lines of legal copy compiled into the binary** |
| `F: src/presentation/profile/viewmodels/notifications_viewmodel.dart` | 48 | MOVE | `shared/notifications/application/notification_settings_controller.dart` | |
| `F: src/presentation/profile/viewmodels/referral_viewmodel.dart` | **1** | **DELETE** | — | One-line orphan; the real one is in `presentation/referral/` |

### `shared/wallet/` — **HOLD on B6**

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/presentation/wallet/screens/wallet_screen.dart` | 926 | HOLD → MERGE (host) | `shared/wallet/presentation/wallet_screen.dart` |
| `F: src/presentation/wallet/viewmodels/wallet_viewmodel.dart` | 127 | HOLD → PORT | `shared/wallet/application/wallet_controller.dart` |
| `F: src/presentation/wallet/viewmodels/wallet_state.dart` | 69 | HOLD → MOVE | `shared/wallet/application/wallet_state.dart` |
| `F: src/data/models/wallet_model.dart` | 378 | HOLD → MERGE (host) | `shared/wallet/data/wallet_dto.dart` |
| `F: src/data/repository/wallet_repository_impl.dart` | 43 | HOLD → MERGE | `shared/wallet/data/wallet_repository.dart` |
| `F: src/domain/repository/wallet_repository.dart` | 24 | HOLD → MERGE | folds into impl |
| `F: src/domain/service/wallet_service.dart` | 24 | HOLD → MERGE | |
| `F: src/di/wallet_providers.dart` | 16 | MOVE | `shared/wallet/application/wallet_providers.dart` |
| `T: features/wallet/presentation/wallet_screen.dart` | 128 | HOLD → DELETE | |
| `T: features/wallet/presentation/topup_sheet.dart` | 113 | HOLD → MERGE | `shared/wallet/presentation/topup_sheet.dart` — food has **no top-up UI** |
| `T: features/wallet/data/wallet_repository.dart` | 47 | HOLD → MERGE → DELETE | contributes top-up / transfer / transfer-to-driver / Razorpay order+verify |
| `T: features/wallet/data/models/wallet_transaction_model.dart` | 32 | HOLD → MERGE → DELETE | |
| `T: features/wallet/application/wallet_providers.dart` | 16 | DELETE | collides with food's by name |

### `shared/address/` — **HOLD on B8**

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/presentation/address/screens/add_address_screen.dart` | 1,436 | HOLD → MERGE (host) | `shared/address/presentation/address_editor_screen.dart` | |
| `F: src/presentation/address/viewmodels/address_viewmodel.dart` | 127 | HOLD → PORT | `shared/address/application/address_controller.dart` | |
| `F: src/data/datasources/address_remote_datasource.dart` | 43 | HOLD → MOVE | `shared/address/data/address_api.dart` | |
| `F: src/data/models/address_model.dart` | 109 | HOLD → MERGE | `shared/address/data/address_dto.dart` | |
| `F: src/di/address_providers.dart` | 8 | MOVE | `shared/address/application/address_providers.dart` | |
| `T: features/home/application/saved_places_provider.dart` | 80 | HOLD → MERGE → DELETE | | **Server-backed vs. Hive-local is the core conflict**: taxi's saved places never leave the device |
| `T: features/home/presentation/saved_places_screen.dart` | 147 | HOLD → MERGE → DELETE | | |
| `T: features/home/data/models/saved_address_model.dart` | 37 | HOLD → MERGE → DELETE | | |
| `T: features/home/presentation/map_picker_screen.dart` | 254 | MOVE | `shared/address/presentation/map_picker_screen.dart` | Food's address screen needs exactly this and doesn't have it |

### `shared/notifications/`, `shared/support/`, `shared/referral/`, `shared/offers/`, `shared/payment/`

| From | Lines | Action | To | Note |
|---|---|---|---|---|
| `F: src/presentation/notifications/notifications_screen.dart` | 286 | MERGE (host) | `shared/notifications/presentation/inbox_screen.dart` | Add a module filter chip row |
| `F: src/presentation/notifications/viewmodels/notification_inbox_viewmodel.dart` | 165 | PORT | `shared/notifications/application/inbox_controller.dart` | |
| `T: features/notifications/presentation/notifications_screen.dart` | 94 | MERGE → DELETE | | |
| `T: features/notifications/presentation/notification_settings_screen.dart` | 59 | PORT | `shared/notifications/presentation/settings_screen.dart` | Food has no per-type notification settings |
| `T: features/notifications/data/models/notification_model.dart` | 31 | MERGE | `shared/notifications/data/notification_dto.dart` | Must carry `module` |
| `T: features/notifications/data/notifications_repository.dart` | 23 | HOLD → MERGE | `shared/notifications/data/notifications_repository.dart` | Two inbox endpoints: `/food/notifications/inbox` and `/users/notifications` |
| `T: features/notifications/application/notifications_providers.dart` | 24 | MERGE → DELETE | | |
| `T: features/support/*` (8 files) | 793 | HOLD → PORT | `shared/support/**` | Ticket model + safety centre + SOS. **`sos_screen` stays taxi-flavoured but SOS itself is app-wide** |
| `F: src/presentation/profile/screens/help_support_screen.dart` | 840 | HOLD → MERGE | `shared/support/presentation/support_home_screen.dart` | |
| `F: src/presentation/chat/**` (2 files) | 570 | HOLD → PORT | `shared/support/presentation/chat/**` | REST+socket chat |
| `F: src/data/datasources/chat_remote_datasource.dart` | 71 | HOLD → MOVE | `shared/support/data/chat_api.dart` | |
| `F: src/data/models/chat_model.dart` | 121 | HOLD → MOVE | `shared/support/data/chat_dto.dart` | |
| `F: src/di/chat_providers.dart` | 8 | MOVE | `shared/support/application/chat_providers.dart` | |
| `T: features/ride/presentation/ride_chat_screen.dart` | 455 | HOLD → REBUILD | `shared/support/presentation/chat/chat_screen.dart` | **Second chat implementation** — socket-only, ride-scoped. Reconcile with food's |
| `T: features/ride/data/models/ride_message_model.dart` | 25 | MERGE | `shared/support/data/chat_dto.dart` | |
| `F: src/presentation/referral/**` (7 files) | 1,146 | MOVE | `shared/referral/**` | Rich UI (ticket card, rotating border, fire-particle share button) |
| `T: features/rewards/presentation/rewards_screen.dart` | 168 | HOLD → MERGE | `shared/referral/presentation/rewards_screen.dart` | |
| `F: src/presentation/offers/screens/all_offers_screen.dart` | 96 | HOLD → MOVE | `shared/offers/presentation/all_offers_screen.dart` | |
| `F: src/presentation/coupons/viewmodels/coupons_viewmodel.dart` | 57 | HOLD → PORT | `shared/offers/application/coupon_controller.dart` | |
| `F: src/presentation/cart/widgets/coupon_sheet.dart` | 332 | HOLD → MOVE | `shared/offers/presentation/coupon_sheet.dart` | Must serve ride fares too |
| `T: features/promo/**` (3 files) | 69 | HOLD → MERGE → DELETE | `shared/offers/**` | |
| `T: features/home/presentation/promo_screen.dart` | 114 | HOLD → MERGE | `shared/offers/presentation/promo_screen.dart` | |
| `F: src/presentation/payment/viewmodels/payment_viewmodel.dart` | 87 | PORT | `shared/payment/application/payment_controller.dart` | |
| `F: src/di/payment_providers.dart` | 17 | MOVE | `shared/payment/application/payment_providers.dart` | |
| `T: features/ride/presentation/ride_completion_payment_sheet.dart` | 185 | MOVE | `shared/payment/presentation/completion_payment_sheet.dart` | Generalises to any module's end-of-job payment |
| `T: features/subscription/**` (4 files) | 328 | HOLD → PORT | `shared/subscription/**` | Currently ride-only; a super-app pass should span modules |

### `shared/activity/` — **HOLD on B7**

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/presentation/orders/screens/orders_screen.dart` | 973 | HOLD → SPLIT | `shared/activity/presentation/activity_screen.dart` (shell + tabs) + `modules/food/presentation/orders/food_activity_row.dart` |
| `F: src/presentation/orders/viewmodels/orders_viewmodel.dart` | 237 | HOLD → SPLIT | `shared/activity/application/activity_controller.dart` + `modules/food/application/food_activity_source.dart` |
| `T: features/ride/presentation/ride_history_screen.dart` | 429 | HOLD → SPLIT | → `modules/taxi/.../ride_activity_row.dart` |
| `T: features/ride/application/ride_history_controller.dart` | 69 | HOLD → PORT | `modules/taxi/application/ride_activity_source.dart` |
| `T: features/ride/application/ride_history_state.dart` | 42 | HOLD → MERGE | |
| `T: features/delivery/presentation/delivery_history_screen.dart` | 56 | HOLD → DELETE | → `modules/parcel/.../parcel_activity_row.dart` |
| `T: features/rental/presentation/rental_history_screen.dart` | 181 | HOLD → DELETE | → `modules/rental/.../rental_activity_row.dart` |
| `T: features/ride/presentation/widgets/recent_activity_card.dart` | 320 | HOLD → MOVE | `shared/activity/presentation/widgets/recent_activity_card.dart` |
| `F: src/presentation/orders/viewmodels/active_order_viewmodel.dart` | 136 | PORT | `shared/activity/application/active_jobs_controller.dart` — generalise to rides/parcels |
| `F: src/presentation/orders/widgets/floating_active_order_card.dart` | 248 | PORT | `shared/activity/presentation/widgets/floating_active_job_card.dart` |

### `shared/search/` — see [Ch. 13](09-maps-search-wallet-activity.md)

| From | Lines | Action | To |
|---|---|---|---|
| `F: src/presentation/search/screens/search_screen.dart` | 1,077 | SPLIT | `shared/search/presentation/search_screen.dart` + `modules/food/presentation/search/*_result_tile.dart` |
| `F: src/presentation/search/viewmodels/search_viewmodel.dart` | 156 | SPLIT | `shared/search/application/search_controller.dart` + `modules/food/application/food_search_source.dart` |
| `F: src/presentation/search/viewmodels/search_state.dart` | 58 | MOVE | `shared/search/application/search_state.dart` |
| `F: src/presentation/search/widgets/voice_search_dialog.dart` | 308 | MOVE | `shared/search/presentation/voice_search_dialog.dart` |
| `F: src/domain/service/search_service.dart` | 190 | SPLIT | `shared/search/data/search_repository.dart` + food source |
| `F: src/data/datasources/search_remote_datasource.dart` | 83 | MOVE | `modules/food/api/datasources/search_remote_datasource.dart` |
| `F: src/data/datasources/search_local_datasource.dart` | 49 | MERGE | `shared/search/data/recent_searches_store.dart` |
| `F: src/data/repository/search_repository_impl.dart` | 58 | MERGE | as above |
| `F: src/domain/repository/search_repository.dart` | 12 | MERGE | |
| `F: src/domain/model/search_result.dart` | 55 | REBUILD | `shared/search/data/search_result.dart` — must be module-tagged and extensible |
| `F: src/di/search_providers.dart` | 38 | MOVE | `shared/search/application/search_providers.dart` |
| `T: features/home/presentation/search_destination_screen.dart` | 926 | **KEEP SEPARATE** | `modules/taxi/presentation/booking/search_destination_screen.dart` |
| `T: features/home/application/ride_search_controller.dart` | 216 | MOVE+NS | `modules/taxi/application/destination_search_controller.dart` |
| `T: features/home/application/ride_search_state.dart` | 83 | MOVE+NS | as above |
| `T: features/home/application/recent_searches_provider.dart` | 40 | MERGE | `shared/search/data/recent_searches_store.dart` |

**Design note.** Food's search finds *content* (restaurants, dishes). Taxi's "search" picks a *destination* — a place autocomplete inside a booking funnel. Collapsing them into one screen would be a UX regression. They stay separate; only the recent-searches store and the search-field component are shared. This is the one place in Chapter 13's brief where the answer is "don't unify".

---

## 3.5 → `modules/food/`

Everything below is **MOVE / MOVE+NS** — food's own vertical, unchanged in behaviour.

### `modules/food/api/`

| From | Lines | To |
|---|---|---|
| `src/core/config/api_config.dart` (`ApiPaths` only) | ~75 | `api/food_endpoints.dart` |
| `src/data/datasources/catalog_remote_datasource.dart` | 265 | `api/datasources/catalog_datasource.dart` |
| `src/data/datasources/order_remote_datasource.dart` | 347 | `api/datasources/order_datasource.dart` |
| `src/data/datasources/order_rtdb_datasource.dart` | 84 | `api/datasources/order_rtdb_datasource.dart` |
| `src/data/datasources/favorites_remote_datasource.dart` | 168 | `api/datasources/favorites_datasource.dart` |

### `modules/food/data/models/` — all MOVE

`order_model` 747 · `restaurant_model` 294 · `food_variant` 141 · `food_model` 164 · `order_pricing` 148 · `cart_item_model` 49 · `category_model` 39 · `promo_banner_model` 82 · `store99_product_dto` 88 · `zone_model` 24 · `active_order_rtdb_model` 70 → `data/models/`
`domain/model/{restaurant_menu_category, store99_brand, store99_cuisine, store99_product}` 128 → `data/models/`

### `modules/food/data/repositories/`

`restaurant_repository_impl` 62 + `domain/repository/restaurant_repository` 16 + `domain/service/restaurant_service` 166 → `repositories/restaurant_repository.dart`
`favorites_repository_impl` 119 + contract 19 → `repositories/favorites_repository.dart`
`store99_repository_impl` 112 + contract 18 + `store99_service` 56 → `repositories/store99_repository.dart`

### `modules/food/application/` — all PORT (Riverpod already 3.x, but rename for namespacing)

`home_viewmodel` 103 · `banners_viewmodel` 29 · `near_you_viewmodel` 73 · `restaurant_list_viewmodel` 127 · `veg_filter_provider` 16 · `zone_viewmodel` 69 · `restaurant_viewmodel` 123 · `restaurant_state` 60 · `restaurant_detail_viewmodel` 13 · `store99_viewmodel` 128 · `store99_state` 56 · `cart_viewmodel` 248 · `checkout_viewmodel` 325 · `favorites_viewmodel` 242 · `orders_viewmodel` 237 · `order_tracking_viewmodel` 509 · `order_conversations_viewmodel` 24
DI: `catalog_providers` 74 · `restaurant_providers` 20 · `order_providers` 13 · `store99_providers` 18 · `favorites_providers` 15 · `location_providers` 6 · `account_providers` 11

`HomeScreen` → `FoodHomeScreen` and every `*ViewModel` → `*Controller` (naming consistency with taxi, and `HomeScreen` collides).

### `modules/food/presentation/` — all MOVE, 3 renames

| From | Lines | To |
|---|---|---|
| `home/home_screen.dart` | 805 | `presentation/home/food_home_screen.dart` **(rename — collides)** |
| `home/screens/home_filter_screen.dart` | 337 | `presentation/home/home_filter_screen.dart` |
| `home/widgets/*` (8 files: `restaurant_card` 1220, `popular_items_list` 472, `home_header_banner` 320, `exclusive_offers_banner` 281, `nearby_restaurants_list` 172, `promo_banner_carousel` 167, `category_list` 147, `popular_brands_list` 115) | 2,894 | `presentation/home/widgets/` |
| `restaurant/screens/*` (5 files) | 4,334 | `presentation/restaurant/` |
| `restaurant/widgets/*` (3 files) | 1,723 | `presentation/restaurant/widgets/` |
| `cart/*` (7 files incl. `cart_screen` 2629) | 4,362 | `presentation/cart/` |
| `orders/screens/*` (5 files) | 4,464 | `presentation/orders/` |
| `orders/widgets/*` (13 files incl. `live_tracking_map` 894) | 2,825 | `presentation/orders/widgets/` (extract map internals → `core/maps`) |
| `orders/utils/reorder.dart` | 64 | `application/reorder.dart` |
| `favorites/favorites_screen.dart` | 565 | `presentation/favorites/` |
| `common/webview_screen.dart` | 259 | `design_system/components/layout/webview_screen.dart` (shared) |

---

## 3.6 → `modules/taxi/`

All **PORT** — every file needs Riverpod 3 / go_router 17 / new client.

| From | Lines | To | Note |
|---|---|---|---|
| `features/home/presentation/home_screen.dart` | 1,380 | `presentation/booking/taxi_home_screen.dart` | **Rename — collides.** Also: strip the service-launcher grid out; that becomes `app/hub/` |
| `features/home/presentation/ride_type_screen.dart` | 625 | `presentation/booking/ride_type_screen.dart` | |
| `features/home/presentation/confirm_booking_screen.dart` | 246 | `presentation/booking/confirm_booking_screen.dart` | |
| `features/home/presentation/finding_driver_screen.dart` | 397 | `presentation/booking/finding_driver_screen.dart` | |
| `features/home/presentation/no_driver_screen.dart` | 27 | `presentation/booking/no_driver_screen.dart` | |
| `features/home/presentation/schedule_ride_sheet.dart` | 80 | `presentation/booking/schedule_ride_sheet.dart` | |
| `features/home/presentation/nearby_driver_markers.dart` | 38 | `presentation/booking/widgets/nearby_driver_markers.dart` | |
| `features/home/presentation/all_services_screen.dart` | 330 | **→ `app/hub/hub_screen.dart`** | This is the super-app hub. It already reads `/users/app-modules` |
| `features/home/data/models/app_module_model.dart` | 37 | **→ `app/hub/app_module_dto.dart`** | |
| `features/home/application/booking_controller.dart` | 239 | `application/booking_controller.dart` | `StateNotifier` → `Notifier` |
| `features/home/application/booking_state.dart` | 108 | `application/booking_state.dart` | |
| `features/home/application/fare_calculator.dart` | 46 | `application/fare_calculator.dart` | |
| `features/home/application/home_providers.dart` | 187 | SPLIT → `application/taxi_providers.dart` + `app/hub/hub_providers.dart` | |
| `features/home/data/home_repository.dart` | 80 | SPLIT → `data/repositories/taxi_repository.dart` + hub | |
| `features/home/data/models/vehicle_type_model.dart` | 42 | `data/models/vehicle_type.dart` | |
| `features/home/data/models/set_price_model.dart` | 41 | `data/models/set_price.dart` | |
| `features/ride/**` (15 files) | 4,223 | `application/` + `data/` + `presentation/tracking|history|rating/` | minus `ride_chat_screen` (→ shared/support) and `ride_completion_payment_sheet` (→ shared/payment) and `ride_history_screen` (→ shared/activity) |
| `features/support/presentation/sos_screen.dart` | 129 | `presentation/sos_screen.dart` **or** `shared/support/` | Decision: SOS is app-wide but its payload is ride-scoped (`?rideId=`). Recommend `shared/support` with an optional job reference |

---

## 3.7 → `modules/parcel/` (from taxi's `features/delivery/`)

All **PORT**. This is a clean lift — the folder is already self-contained.

| From | Lines | To |
|---|---|---|
| `features/delivery/presentation/delivery_address_screen.dart` | 1,165 | `presentation/parcel_address_screen.dart` |
| `features/delivery/presentation/delivery_vehicle_screen.dart` | 732 | `presentation/parcel_vehicle_screen.dart` |
| `features/delivery/presentation/new_delivery_screen.dart` | 375 | `presentation/new_parcel_screen.dart` |
| `features/delivery/presentation/finding_captain_screen.dart` | 285 | `presentation/finding_captain_screen.dart` |
| `features/delivery/presentation/delivery_contacts_sheet.dart` | 278 | `presentation/widgets/parcel_contacts_sheet.dart` |
| `features/delivery/presentation/delivery_category_vehicles_screen.dart` | 219 | `presentation/parcel_category_vehicles_screen.dart` |
| `features/delivery/presentation/delivery_history_screen.dart` | 56 | DELETE → `shared/activity` row renderer |
| `features/delivery/application/delivery_booking_controller.dart` | 260 | `application/parcel_booking_controller.dart` |
| `features/delivery/application/delivery_categories.dart` | 65 | `application/parcel_categories.dart` |
| `features/delivery/application/delivery_providers.dart` | 14 | `application/parcel_providers.dart` |
| `features/delivery/data/delivery_repository.dart` | 107 | `data/repositories/parcel_repository.dart` |
| `features/delivery/data/models/{delivery,parcel}_model.dart` | 67 | `data/models/` |

**Naming warning:** food's push payloads already use `delivery_` prefixes for *food* delivery (`delivery_accepted`, `delivery_drop_otp`). Renaming taxi's delivery feature to "parcel" removes a genuine ambiguity — do it, and make sure the backend's `module` discriminator (B4) distinguishes them.

---

## 3.8 → `modules/rental/` (from taxi's `features/rental/`)

All **PORT**, clean lift.

| From | Lines | To |
|---|---|---|
| `features/rental/presentation/rental_booking_screen.dart` | 220 | `presentation/rental_booking_screen.dart` |
| `features/rental/presentation/rental_vehicles_screen.dart` | 116 | `presentation/rental_vehicles_screen.dart` |
| `features/rental/presentation/rental_history_screen.dart` | 181 | DELETE → `shared/activity` row renderer |
| `features/rental/application/rental_providers.dart` | 21 | `application/rental_providers.dart` |
| `features/rental/data/rental_repository.dart` | 76 | `data/repositories/rental_repository.dart` |
| `features/rental/data/models/rental_vehicle_model.dart` | 105 | `data/models/rental_vehicle.dart` |
| `features/rental/data/models/rental_booking_model.dart` | 48 | `data/models/rental_booking.dart` |

---

## 3.9 Splitting taxi's `api_constants.dart`

The 110-line file fans out across four destinations. Concrete mapping:

| Destination | Endpoint groups |
|---|---|
| `shared/auth/api/` | `sendOtp`, `verifyOtp`, `otpLogin`, `register`, `signup`, `login` |
| `shared/profile/api/` | `me`, `profileImage`, `deleteRequest` |
| `core/push/` | `fcmToken` |
| `app/hub/` | `bootstrap`, `appModules`, `settings`, `zones`, `serviceLocations`, `serviceStores` |
| `shared/wallet/api/` | `wallet`, `walletTopup`, `walletTransfer`, `walletTransferDriver`, `walletRazorpay*`, `walletPhonepe*` |
| `shared/offers/api/` | `promoValidate`, `promoAvailable` |
| `shared/notifications/api/` | `notifications` |
| `shared/subscription/api/` | `subscriptionPlans`, `mySubscriptions`, `buySubscription` |
| `shared/support/api/` | `supportTitles`, `supportTickets`, `myTickets`, `sos` |
| `shared/referral/api/` | `referralsTranslation`, `referralsSettings` |
| `core/media/` | `uploadImage` |
| `core/payment/` | `paymentGateway` |
| `modules/taxi/api/` | `rides`, `activeRide`, `availableDrivers`, `rideTipSettings`, `vehicleTypes`, `vehicleMapIcons`, `setPrices`, `intercityPackages`, `banners` |
| `modules/parcel/api/` | `deliveries`, `goodsTypes` |
| `modules/rental/api/` | `rentalVehicles`, `rentalQuoteRequests`, `rentalBookings`, `activeRentalBooking`, `rentalAdvance*` |
| **unclaimed** | `buses`, `busBookings*`, `pooling`, `poolingBookings*` — **6 endpoints with no client code.** Two future modules the backend already has |

---

## Chapter 4 — Deletion list

### 4.1 Files deleted outright (superseded, nothing preserved)

| File | Lines | Why |
|---|---|---|
| `T: core/network/api_client.dart` | 40 | Food's 354-line client wins |
| `T: core/network/dio_client.dart` | 40 | Ditto |
| `T: core/services/razorpay_service.dart` | 54 | Food's `payment_gateway.dart` (272) wins |
| `T: core/services/notification_service.dart` | 98 | Will not compile on `flutter_local_notifications` 22; food's `push_service` wins |
| `T: features/profile/presentation/profile_screen.dart` | 280 | → `ProfileSection` contributions |
| `T: features/wallet/presentation/wallet_screen.dart` | 128 | Food's 926-line screen wins |
| `T: features/settings/presentation/about_screen.dart` | 85 | Food's CMS-driven About (880) wins |
| `T: features/auth/application/auth_providers.dart` | 14 | Collides; food's wins |
| `T: features/wallet/application/wallet_providers.dart` | 16 | Collides; food's wins |
| `F: src/presentation/profile/viewmodels/referral_viewmodel.dart` | **1** | Orphan stub from an abandoned move |
| **Subtotal** | **~756** | |

### 4.2 Files that die by merging (their content survives elsewhere)

| File | Lines | Absorbed into |
|---|---|---|
| `T: core/theme/app_colors.dart` | 69 | `design_system/tokens/color_tokens.dart` + `module_accent.dart` |
| `T: core/theme/app_text_styles.dart` | 63 | `design_system/tokens/typography.dart` |
| `T: core/theme/app_theme.dart` | 201 | `design_system/theme/app_theme.dart` |
| `T: core/providers/theme_provider.dart` | 41 | `theme_controller.dart` |
| `T: core/storage/secure_storage_service.dart` | 19 | `core/storage/token_storage.dart` |
| `T: core/network/api_exception.dart` | 44 | `core/error/error_mapper.dart` |
| `T: core/utils/snackbar_utils.dart` | 48 | `components/feedback/` |
| `T: core/services/location_service.dart` | 137 | `core/location/geocode_cache.dart` |
| `T: shared/widgets/primary_button.dart` + `secondary_button.dart` | 138 | `components/buttons/app_button.dart` |
| `T: shared/widgets/app_text_field.dart` | 61 | `components/inputs/app_text_field.dart` |
| `T: shared/widgets/empty_state.dart` | 59 | `components/media/empty_state.dart` |
| `T: shared/widgets/shimmer_widgets.dart` + `loading_widget.dart` | 114 | `components/skeletons/` |
| `T: shared/widgets/app_bottom_navigation_bar.dart` | 121 | `components/nav/app_bottom_nav.dart` |
| `T: features/auth/*` (repo, models, controller, state, 3 screens) | ~870 | `shared/auth/**` |
| `T: features/wallet/{data,models}` | 79 | `shared/wallet/**` |
| `T: features/notifications/{data,application}` | 78 | `shared/notifications/**` |
| `T: features/promo/**` | 69 | `shared/offers/**` |
| `T: features/home/{saved_places_provider, saved_places_screen, saved_address_model}` | 264 | `shared/address/**` |
| `T: features/home/application/recent_searches_provider.dart` | 40 | `shared/search/data/recent_searches_store.dart` |
| `T: features/{ride,delivery,rental}/…history_screen.dart` | 666 | `shared/activity/**` |
| `F: src/core/utils/{referral,refresh}_audio_player.dart` | 137 | `core/audio/audio_service.dart` |
| `F: src/core/utils/map_styles.dart` | 26 | `core/maps/map_style.dart` |
| `F: src/platform/network/network_status_provider.dart` | 58 | `core/connectivity/connectivity_service.dart` |
| `F: src/domain/repository/*` (6 abstract contracts) | 132 | folded into their impls |
| `F: src/presentation/profile/screens/{privacy_policy,terms_conditions}_screen.dart` | 1,313 | CMS-backed `static_content_screen` |
| `F: src/presentation/common_widgets/{primary_button, custom_text_field, empty_state_widget}` | 167 | design system |
| **Subtotal** | **~5,000+** | |

### 4.3 Duplicate models

| Concept | Food | Taxi | Resolution |
|---|---|---|---|
| User | `user_model.dart` 133 | `user_model.dart` 69 | One `UserDto` in `shared/profile`; `currentRideId` → taxi module state; `walletBalance` → wallet |
| Auth session | `auth_session.dart` 34 | `AuthSession` inside `auth_repository.dart` | One `SessionDto`. **Both classes are literally named `AuthSession`** |
| Wallet txn | inside `wallet_model.dart` 378 | `wallet_transaction_model.dart` 32 | One `WalletTransactionDto` with a `module` tag |
| Notification | inside inbox viewmodel | `notification_model.dart` 31 | One `NotificationDto` with `module` + `deepLink` |
| Address / place | `address_model.dart` 109 | `saved_address_model.dart` 37 | One `AddressDto`; taxi's `label`/`type` become optional fields |
| Promo | `promo_banner_model.dart` 82 | `promo_model.dart` 37 | Two genuinely different things (home banner vs. coupon). **Keep both, rename**: `HomeBannerDto` and `CouponDto` |
| Chat message | `chat_model.dart` 121 | `ride_message_model.dart` 25 | One `ChatMessageDto` |
| Vehicle | — | `vehicle_type_model.dart` 42, `rental_vehicle_model.dart` 105 | Distinct; keep in their modules |

### 4.4 Duplicate services — final ownership

| Service | Winner | Deleted |
|---|---|---|
| HTTP client | `F: api_client.dart` (354) | `T: api_client.dart` (40), `T: dio_client.dart` (40) |
| Socket | **new** `SocketChannel` | both (174 + 125) — logic salvaged from each |
| Push | `F: push_service.dart` (457) | `T: notification_service.dart` (98) |
| Location — GPS + structured address | `F: location_service.dart` (281) | — |
| Location — geocode caching | `T: location_service.dart` (137) | — (the two are complementary, not competing) |
| Payments | `F: payment_gateway.dart` (272) | `T: razorpay_service.dart` (54) |
| Secure storage | `F: token_storage.dart` (64) + taxi's Android option | `T: secure_storage_service.dart` (19) |
| Audio | **new** `AudioService` | 3 files (75 + 62 + 42) |
| Connectivity | **new** `ConnectivityService` (`connectivity_plus`) | `F: network_status_provider.dart` (58) |
| Maps helpers | taxi's 5 files | `F: map_styles.dart` (26) |
| Deep links | `F: deep_link_service.dart` (115), registry-driven | — |

### 4.5 Non-Dart deletions

| Path | Why |
|---|---|
| `flutter_taxi_user/linux/`, `macos/`, `windows/` | Unused desktop scaffolding; food has none |
| `flutter_taxi_user/Taxi_userapp.docx` | Not source |
| `flutter_taxi_user/backend/taxi-new/{fix*.js, admins_diff.txt, *.log, scratch/, WhatsApp Image*.jpeg, driver_sample_upload.xlsx}` | Scratch files in a backend folder |
| `Food_user/flutter-food-user-application/backend/food-backend/` | Empty |
| One of the two `google-services.json` | Only one can exist — see B3 |
| `flutter_taxi_user/assets/*.png` (the 20 oversized ones) | Re-encode to WebP; see [Ch. 17](10-performance-and-app-size.md) |

### 4.6 Deletion summary

| Category | Files | Lines |
|---|---|---|
| Deleted outright | 10 | ~756 |
| Died by merging | ~60 | ~5,000 |
| **Total removed** | **~70** | **~5,750** |
| Files after merge (estimate) | ~370 | ~69,000 |

The line count drops ~8 % while the app gains four modules, a hub, a unified activity page, and a real design system. The *structural* saving is bigger than the line saving: 12 duplicated platform services become 10 single-owner ones, and every future module inherits them for free.
