part of 'instruments_bloc.dart';

sealed class InstrumentsEvent extends Equatable {
  const InstrumentsEvent();

  @override
  List<Object?> get props => [];
}

class InstrumentsRequested extends InstrumentsEvent {
  const InstrumentsRequested();
}