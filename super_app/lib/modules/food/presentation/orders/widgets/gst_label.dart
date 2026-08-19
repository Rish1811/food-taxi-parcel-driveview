/// "GST (5%)" when the rate is known, plain "GST" when it is not.
///
/// Never guesses a percentage: an order placed before the server started
/// sending the rates has none, and inventing one would put a wrong number on a
/// bill the customer already paid.
String gstLabel(String name, double rate) {
  if (rate <= 0) return name;
  final shown =
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);
  return '$name ($shown%)';
}
