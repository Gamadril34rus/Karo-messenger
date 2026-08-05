// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../data/nearby_user.dart';

// Events
sealed class NearbyEvent extends Equatable { @override List<Object?> get props => []; }
final class NearbyLoadRequested extends NearbyEvent {}

// States
sealed class NearbyState extends Equatable { @override List<Object?> get props => []; }
final class NearbyInitial extends NearbyState {}
final class NearbyLoading extends NearbyState {}
final class NearbyLoaded extends NearbyState {
  final List<NearbyUser> users;
  NearbyLoaded({required this.users});
  @override List<Object?> get props => [users];
}
final class NearbyError extends NearbyState {
  final String message;
  NearbyError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  final CharoRepository _repository;
  NearbyBloc({required CharoRepository repository}) : _repository = repository, super(NearbyInitial()) {
    on<NearbyLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(NearbyLoadRequested event, Emitter<NearbyState> emit) async {
    emit(NearbyLoading());
    try {
      final users = await _repository.getNearbyUsers(0, 0);
      emit(NearbyLoaded(users: users));
    } on CharoApiException catch (e) {
      emit(NearbyError(message: e.message));
    }
  }
}
