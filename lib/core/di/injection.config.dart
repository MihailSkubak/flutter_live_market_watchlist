// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../feed/resilience/connection_manager.dart' as _i389;
import '../../feed/resilience/tick_ordering_guard.dart' as _i562;
import '../../feed/transport/dio_feed_api.dart' as _i23;
import '../../feed/transport/feed_api.dart' as _i589;
import '../../native/android/android_connectivity_monitor.dart' as _i1057;
import '../../native/android/android_token_storage.dart' as _i505;
import '../../native/connectivity_monitor.dart' as _i187;
import '../../native/token_storage.dart' as _i706;
import '../../presentation/instruments/bloc/instruments_bloc.dart' as _i753;
import '../../presentation/watchlist/bloc/watchlist_bloc.dart' as _i670;
import 'network_module.dart' as _i567;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final networkModule = _$NetworkModule();
  gh.lazySingleton<_i361.Dio>(() => networkModule.dio());
  gh.lazySingleton<_i562.TickOrderingGuard>(() => _i562.TickOrderingGuard());
  gh.lazySingleton<_i706.TokenStorage>(() => _i505.AndroidTokenStorage());
  gh.lazySingleton<_i589.FeedApi>(() => _i23.DioFeedApi(gh<_i361.Dio>()));
  gh.lazySingleton<_i187.ConnectivityMonitor>(
    () => _i1057.AndroidConnectivityMonitor(),
  );
  gh.lazySingleton<_i389.ConnectionManager>(
    () => _i389.ConnectionManager(
      gh<_i589.FeedApi>(),
      gh<_i187.ConnectivityMonitor>(),
      gh<_i706.TokenStorage>(),
    ),
  );
  gh.factory<_i670.WatchlistBloc>(
    () => _i670.WatchlistBloc(
      gh<_i389.ConnectionManager>(),
      gh<_i562.TickOrderingGuard>(),
    ),
  );
  gh.factory<_i753.InstrumentsBloc>(
    () => _i753.InstrumentsBloc(gh<_i589.FeedApi>()),
  );
  return getIt;
}

class _$NetworkModule extends _i567.NetworkModule {}
