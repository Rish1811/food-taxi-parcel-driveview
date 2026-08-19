import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentMethodModel {
  final String id;
  final String type; // 'Card', 'UPI', 'Wallet', 'NetBanking'
  final String title;
  final String subtitle;
  final bool isDefault;

  const PaymentMethodModel({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  PaymentMethodModel copyWith({
    String? id,
    String? type,
    String? title,
    String? subtitle,
    bool? isDefault,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

final paymentViewModelProvider = NotifierProvider<PaymentViewModel, List<PaymentMethodModel>>(() {
  return PaymentViewModel();
});

class PaymentViewModel extends Notifier<List<PaymentMethodModel>> {
  @override
  List<PaymentMethodModel> build() {
    return const [
      PaymentMethodModel(
        id: 'pay-1',
        type: 'UPI',
        title: 'Google Pay UPI',
        subtitle: 'tanu.chouhan@okicici',
        isDefault: true,
      ),
      PaymentMethodModel(
        id: 'pay-2',
        type: 'Card',
        title: 'HDFC Bank Credit Card',
        subtitle: '•••• •••• •••• 4921',
        isDefault: false,
      ),
      PaymentMethodModel(
        id: 'pay-3',
        type: 'UPI',
        title: 'PhonePe UPI',
        subtitle: '9876543210@ybl',
        isDefault: false,
      ),
    ];
  }

  void addPaymentMethod(PaymentMethodModel method) {
    if (method.isDefault) {
      state = state.map((m) => m.copyWith(isDefault: false)).toList();
    }
    state = [...state, method];
  }

  void removePaymentMethod(String id) {
    state = state.where((m) => m.id != id).toList();
    if (state.isNotEmpty && !state.any((m) => m.isDefault)) {
      state = [
        state.first.copyWith(isDefault: true),
        ...state.sublist(1),
      ];
    }
  }

  void setDefaultPaymentMethod(String id) {
    state = state.map((m) => m.copyWith(isDefault: m.id == id)).toList();
  }
}
