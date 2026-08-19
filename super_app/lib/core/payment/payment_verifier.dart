/// Server-side confirmation of a gateway payment.
///
/// The client-side Razorpay success callback is never sufficient on its own —
/// the signature triple has to be verified by the backend before money is
/// treated as received. This interface is what lets `core/payment` do that
/// without knowing whether the thing being paid for is a food order, a ride,
/// a parcel or a rental advance.
///
/// Each module supplies its own implementation against its own endpoint
/// (`/food/orders/verify-payment`, `/taxi/rides/:id/complete-payment/...`).
abstract interface class PaymentVerifier {
  /// Confirms the payment with the backend and returns the updated job payload.
  Future<Map<String, dynamic>> verify({
    required String jobId,
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String gatewaySignature,
  });

  /// Re-reads the job.
  ///
  /// The gateway webhook is the real source of truth: if client verification
  /// fails but the webhook already landed, the payment did succeed. Rather than
  /// declaring failure on a client-side hiccup, the gateway re-reads and asks
  /// [isPaid].
  Future<Map<String, dynamic>> fetchJob(String jobId);

  /// Whether [job] shows the payment as settled.
  ///
  /// Per-module because the payload shape differs — food nests it under
  /// `order.payment.status`.
  bool isPaid(Map<String, dynamic> job);
}
