import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/charo_repository.dart';
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
  final CharoRepository _repository;
  final WsClient _wsClient;

  CallsBloc({required CharoRepository repository, required WsClient wsClient})
      : _repository = repository, _wsClient = wsClient, super(CallsInitial()) {
    on<CallsLoadRequested>(_onLoadRequested);
    on<CallsCallInitiated>(_onCallInitiated);
  }

  Future<void> _onLoadRequested(CallsLoadRequested event, Emitter<CallsState> emit) async {
    emit(CallsLoading());
    try {
      final calls = await _repository.getCallsHistory();
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
