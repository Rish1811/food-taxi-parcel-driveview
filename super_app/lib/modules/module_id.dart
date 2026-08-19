/// Stable identity for a super-app module.
///
/// One value does four jobs at once: it is the **route prefix** (`/food/…`),
/// the **push discriminator** (`data.module`), the **activity/analytics tag**,
/// and the key modules are registered under.
///
/// Because of that, [name] is effectively public API. Renaming a value after
/// release breaks deep links already shared, push payloads already queued on
/// FCM's servers, and historical analytics. Pick it once.
enum ModuleId {
  food,
  taxi,
  parcel,
  rental;

  /// Tolerant parse for push payloads and deep links, which may carry
  /// nothing, an unknown module, or a value from a newer app version.
  static ModuleId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final needle = raw.trim().toLowerCase();
    for (final value in values) {
      if (value.name == needle) return value;
    }
    return null;
  }

  /// `/food/restaurants/12` -> [ModuleId.food]; `/wallet` -> null (shared).
  static ModuleId? fromLocation(String location) {
    final segments = Uri.parse(location).pathSegments;
    if (segments.isEmpty) return null;
    return tryParse(segments.first);
  }

  /// The route every module namespaces its subtree under.
  String get routePrefix => '/$name';
}
