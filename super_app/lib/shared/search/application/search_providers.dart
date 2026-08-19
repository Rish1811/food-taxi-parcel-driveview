import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/food/api/datasources/search_local_datasource.dart';
import 'package:superapp_user/modules/food/api/datasources/search_remote_datasource.dart';
import 'package:superapp_user/modules/food/data/repositories/search_repository_impl.dart';
import 'package:superapp_user/modules/food/data/contracts/search_repository.dart';
import 'package:superapp_user/shared/search/data/search_service.dart';
import 'package:superapp_user/core/speech/speech_service.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/zone_viewmodel.dart';

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  return SearchLocalDataSourceImpl();
});

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSourceImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    () => ref.read(currentZoneIdProvider),
  );
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final remote = ref.watch(searchRemoteDataSourceProvider);
  final local = ref.watch(searchLocalDataSourceProvider);
  return SearchRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
  );
});

final searchServiceProvider = Provider<SearchService>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchService(repository);
});
