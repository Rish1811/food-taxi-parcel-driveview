class SocketEvents {
  SocketEvents._();

  static const String error = 'errorMessage';

  // Ride room lifecycle
  static const String rideJoin = 'ride:join';
  static const String rideRejoinCurrent = 'ride:rejoin-current';
  static const String rideJoined = 'ride:joined';
  static const String rideState = 'ride:state';
  static const String rideStatusUpdate = 'ride:status:update';
  static const String rideStatusUpdated = 'ride:status:updated';
  static const String rideDriverLocationUpdate = 'ride:driver-location:update';
  static const String rideDriverLocationUpdated = 'ride:driver-location:updated';
  static const String rideDriverRouteUpdated = 'ride:driver-route:updated';
  static const String rideMessageSend = 'ride:message:send';
  static const String rideMessageNew = 'ride:message:new';

  // Dispatch (server -> rider), delivered on the rider's personal room
  // `user:<id>` which the server joins automatically on connect.
  static const String rideSearchUpdate = 'rideSearchUpdate';
  static const String rideAccepted = 'rideAccepted';
  static const String rideCancelled = 'rideCancelled';
  static const String rideRequestClosed = 'rideRequestClosed';
}
