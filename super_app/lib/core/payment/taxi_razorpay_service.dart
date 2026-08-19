import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckoutRequest {
  final String keyId;
  final String orderId;
  final double amount;
  final String name;
  final String description;
  final String? contact;
  final String? email;

  const RazorpayCheckoutRequest({
    required this.keyId,
    required this.orderId,
    required this.amount,
    required this.name,
    required this.description,
    this.contact,
    this.email,
  });
}

class RazorpayService {
  Razorpay? _razorpay;

  void open({
    required RazorpayCheckoutRequest request,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
    void Function(ExternalWalletResponse response)? onExternalWallet,
  }) {
    _razorpay?.clear();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) => onSuccess(r));
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) => onError(r));
    if (onExternalWallet != null) {
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) => onExternalWallet(r));
    }

    _razorpay!.open({
      'key': request.keyId,
      'order_id': request.orderId,
      'amount': (request.amount * 100).round(),
      'name': request.name,
      'description': request.description,
      'prefill': {
        if (request.contact != null && request.contact!.isNotEmpty) 'contact': request.contact,
        if (request.email != null && request.email!.isNotEmpty) 'email': request.email,
      },
    });
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
