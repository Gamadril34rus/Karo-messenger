import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
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
  final ApiClient _apiClient;
  NearbyBloc({required ApiClient apiClient}) : _apiClient = apiClient, super(NearbyInitial()) {
    on<NearbyLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(NearbyLoadRequested event, Emitter<NearbyState> emit) async {
    emit(NearbyLoading());
    try {
      final response = await _apiClient.get('/api/v1/nearby');
      final users = (response.asList).map<NearbyUser>((json) => NearbyUser(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        distance: json['distance'] as String? ?? '? м',
        status: json['status'] as String?,
      )).toList();
      emit(NearbyLoaded(users: users));
    } on CharoApiException catch (e) {
      emit(NearbyError(message: e.message));
    }
  }
}
