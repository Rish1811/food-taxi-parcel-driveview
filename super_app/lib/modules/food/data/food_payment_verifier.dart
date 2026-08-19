import 'package:superapp_user/core/payment/payment_verifier.dart';
import 'package:superapp_user/modules/food/api/datasources/order_remote_datasource.dart';

/// Food's [PaymentVerifier], backed by `POST /food/orders/verify-payment`.
class FoodPaymentVerifier implements PaymentVerifier {
  const FoodPaymentVerifier(this._orders);

  final OrderRemoteDataSource _orders;

  @override
  Future<Map<String, dynamic>> verify({
    required String jobId,
    required String gatewayOrderId,
    required String gatewayPaymentId,
    required String gatewaySignature,
  }) {
    return _orders.verifyPayment(
      orderId: jobId,
      razorpayOrderId: gatewayOrderId,
      razorpayPaymentId: gatewayPaymentId,
      razorpaySignature: gatewaySignature,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchJob(String jobId) => _orders.getOrder(jobId);

  @override
  bool isPaid(Map<String, dynamic> job) {
    final payment = (job['order'] as Map?)?['payment'] as Map?;
    return payment?['status'] == 'paid';
  }
}
