import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/ws_client.dart';
import '../../data/call_item.dart';

// Events
sealed class CallsEvent extends Equatable { @override List<Object?> get props => []; }
final class CallsLoadRequested extends CallsEvent {}
final class CallsCallInitiated extends CallsEvent {
  final String targetUserId;
  final bool isVideo;
  CallsCallInitiated({required this.targetUserId, required this.isVideo});
  @override List<Object?> get props => [targetUserId, isVideo];
}

// States
sealed class CallsState extends Equatable { @override List<Object?> get props => []; }
final class CallsInitial extends CallsState {}
final class CallsLoading extends CallsState {}
final class CallsLoaded extends CallsState {
  final List<CallItem> calls;
  CallsLoaded({required this.calls});
  @override List<Object?> get props => [calls];
}
final class CallsError extends CallsState {
  final String message;
  CallsError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class CallsBloc extends Bloc<CallsEvent, CallsState> {
  final ApiClient _apiClient;
  final WsClient _wsClient;

  CallsBloc({required ApiClient apiClient, required WsClient wsClient})
      : _apiClient = apiClient, _wsClient = wsClient, super(CallsInitial()) {
    on<CallsLoadRequested>(_onLoadRequested);
    on<CallsCallInitiated>(_onCallInitiated);
  }

  Future<void> _onLoadRequested(CallsLoadRequested event, Emitter<CallsState> emit) async {
    emit(CallsLoading());
    try {
      final response = await _apiClient.get('/api/v1/calls/history');
      final calls = (response.asList).map<CallItem>((json) => CallItem(
        id: json['id'] as String,
        name: json['caller']?['display_name'] as String?,
        avatarUrl: json['caller']?['avatar_url'] as String?,
        type: json['type'] as String? ?? 'voice',
        direction: json['direction'] as String? ?? 'outgoing',
        status: json['status'] as String? ?? 'ended',
        time: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : DateTime.now(),
        duration: json['duration_sec'] as int?,
      )).toList();
      emit(CallsLoaded(calls: calls));
    } on CharoApiException catch (e) {
      emit(CallsError(message: e.message));
    }
  }

  void _onCallInitiated(CallsCallInitiated event, Emitter<CallsState> emit) {
    _wsClient.send('call.initiate', {
      'targetUserId': event.targetUserId,
      'type': event.isVideo ? 'video' : 'voice',
    });
  }
}
