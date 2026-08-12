part of 'instruments_bloc.dart';

sealed class InstrumentsState extends Equatable {
  const InstrumentsState();

  @override
  List<Object?> get props => [];
}

class InstrumentsInitial extends InstrumentsState {
  const InstrumentsInitial();
}

class InstrumentsLoading extends InstrumentsState {
  const InstrumentsLoading();
}

class InstrumentsLoaded extends InstrumentsState {
  final List<Instrument> instruments;

  const InstrumentsLoaded(this.instruments);

  @override
  List<Object?> get props => [instruments];
}

class InstrumentsError extends InstrumentsState {
  final String message;

  const InstrumentsError(this.message);

  @override
  List<Object?> get props => [message];
}