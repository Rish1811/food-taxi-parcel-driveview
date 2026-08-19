import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared veg-only filter, toggled from both the Home search bar pill and
/// the Profile "Veg Mode" switch so they always reflect the same state.
final vegFilterProvider = NotifierProvider<VegFilterNotifier, bool>(() {
  return VegFilterNotifier();
});

class VegFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;

  void toggle() => state = !state;
}
