import '../data/models/delivery_order.dart';

sealed class OrdersState {
  const OrdersState();
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  const OrdersLoaded({
    required this.availableOrders,
    required this.currentOrder,
  });

  final List<DeliveryOrder> availableOrders;
  final DeliveryOrder? currentOrder;

  bool get hasActiveOrder => currentOrder != null;

  OrdersLoaded copyWith({
    List<DeliveryOrder>? availableOrders,
    DeliveryOrder? Function()? currentOrder,
  }) {
    return OrdersLoaded(
      availableOrders: availableOrders ?? this.availableOrders,
      currentOrder: currentOrder != null ? currentOrder() : this.currentOrder,
    );
  }
}

class OrdersError extends OrdersState {
  const OrdersError(this.message);
  final String message;
}
