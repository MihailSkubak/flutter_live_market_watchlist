import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../feed/models/instrument.dart';
import '../../../feed/transport/feed_api.dart';

part 'instruments_event.dart';
part 'instruments_state.dart';

/// Loads the static instrument list once at app startup. Uses its own
/// login call rather than sharing ConnectionManager's token -- keeps this
/// bloc independently testable and decoupled from live-stream timing.
@injectable
class InstrumentsBloc extends Bloc<InstrumentsEvent, InstrumentsState> {
  final FeedApi _api;

  InstrumentsBloc(this._api) : super(const InstrumentsInitial()) {
    on<InstrumentsRequested>(_onRequested);
  }

  Future<void> _onRequested(
    InstrumentsRequested event,
    Emitter<InstrumentsState> emit,
  ) async {
    emit(const InstrumentsLoading());
    try {
      final token = await _api.login();
      final instruments = await _api.fetchInstruments(token.value);
      emit(InstrumentsLoaded(instruments));
    } catch (_) {
      emit(const InstrumentsError('Could not load instruments'));
    }
  }
}