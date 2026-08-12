import 'package:equatable/equatable.dart';

class AuthToken extends Equatable {
  final String value;
  final int expiresInSeconds;

  const AuthToken({required this.value, required this.expiresInSeconds});

  @override
  List<Object?> get props => [value, expiresInSeconds];
}