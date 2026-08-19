// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Suvio';

  @override
  String exitMessage(Object user) {
    return 'Hello $user';
  }

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get cart => 'Cart';

  @override
  String get orders => 'Orders';

  @override
  String get profile => 'Profile';

  @override
  String get add => 'ADD';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get addItems => 'Add Items';

  @override
  String get viewCart => 'View Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get proceedToPayment => 'Proceed to Payment';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get billDetails => 'Bill Details';

  @override
  String get itemTotal => 'Item Total';

  @override
  String get deliveryFee => 'Delivery Fee';

  @override
  String get platformFee => 'Platform Fee';

  @override
  String get taxesAndCharges => 'GST / Taxes';

  @override
  String get discount => 'Discount';

  @override
  String get couponDiscount => 'Coupon Discount';

  @override
  String get walletDiscount => 'Wallet Discount';

  @override
  String get packingCharges => 'Packing Charges';

  @override
  String get tip => 'Tip';

  @override
  String get ratings => 'Ratings';

  @override
  String get prepTime => 'Prep Time';

  @override
  String get calories => 'Calories';

  @override
  String get orderPlaced => 'Order placed!';

  @override
  String get orderConfirmed => 'Order confirmed!';

  @override
  String get trackOrder => 'Track Order';

  @override
  String get continueShopping => 'Continue Shopping';

  @override
  String get reorderItems => 'Reorder these items';

  @override
  String get deliveryAddress => 'Delivering to';

  @override
  String get cookingRequests => 'Cooking requests';

  @override
  String get replaceCart => 'Replace Cart?';
}
