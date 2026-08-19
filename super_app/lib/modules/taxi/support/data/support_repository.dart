import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/support/data/models/support_ticket_model.dart';

class SupportRepository {
  final TaxiApiClient api;

  SupportRepository(this.api);

  Future<List<SupportTitleModel>> getTitles() async {
    final data = await api.get(ApiConstants.supportTitles, query: {'userType': 'user'});
    final results = (data['results'] as List? ?? []);
    return results.map((e) => SupportTitleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SupportTicketModel>> getMyTickets() async {
    final data = await api.get(ApiConstants.myTickets);
    final results = (data['results'] as List? ?? []);
    return results.map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<SupportTicketModel> getTicketDetail(String ticketCode) async {
    final data = await api.get('${ApiConstants.supportTickets}/$ticketCode');
    return SupportTicketModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SupportTicketModel> createTicket({String? titleId, String? title, required String message}) async {
    final data = await api.post(ApiConstants.supportTickets, data: {
      if (titleId != null) 'titleId': titleId,
      if (title != null) 'title': title,
      'message': message,
    });
    return SupportTicketModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SupportTicketModel> replyToTicket(String ticketCode, String message) async {
    final data = await api.post('${ApiConstants.supportTickets}/$ticketCode/reply', data: {'message': message});
    return SupportTicketModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> triggerSos({
    String? rideId,
    required double lat,
    required double lng,
    String? notes,
  }) {
    return api.post(ApiConstants.sos, data: {
      if (rideId != null) 'rideId': rideId,
      'serviceType': 'ride',
      'location': {'lat': lat, 'lng': lng},
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }
}
