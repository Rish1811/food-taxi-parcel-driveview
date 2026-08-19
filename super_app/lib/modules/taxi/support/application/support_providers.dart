import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/support/data/models/support_ticket_model.dart';
import 'package:superapp_user/modules/taxi/support/data/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(taxiApiClientProvider));
});

final supportTitlesProvider = FutureProvider.autoDispose<List<SupportTitleModel>>((ref) {
  return ref.watch(supportRepositoryProvider).getTitles();
});

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicketModel>>((ref) {
  return ref.watch(supportRepositoryProvider).getMyTickets();
});

final ticketDetailProvider =
    FutureProvider.autoDispose.family<SupportTicketModel, String>((ref, ticketCode) {
  return ref.watch(supportRepositoryProvider).getTicketDetail(ticketCode);
});
