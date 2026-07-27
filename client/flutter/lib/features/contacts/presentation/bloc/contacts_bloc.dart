import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../data/contact_item.dart';

// Events
sealed class ContactsEvent extends Equatable { @override List<Object?> get props => []; }
final class ContactsLoadRequested extends ContactsEvent {}
final class ContactsSyncRequested extends ContactsEvent {}
final class ContactAdded extends ContactsEvent {
  final String identifier;
  ContactAdded({required this.identifier});
  @override List<Object?> get props => [identifier];
}
final class ContactDeleted extends ContactsEvent {
  final String userId;
  ContactDeleted({required this.userId});
  @override List<Object?> get props => [userId];
}

// States
sealed class ContactsState extends Equatable { @override List<Object?> get props => []; }
final class ContactsInitial extends ContactsState {}
final class ContactsLoading extends ContactsState {}
final class ContactsLoaded extends ContactsState {
  final List<ContactItem> contacts;
  ContactsLoaded({required this.contacts});
  @override List<Object?> get props => [contacts];
}
final class ContactsError extends ContactsState {
  final String message;
  ContactsError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final ApiClient _apiClient;
  ContactsBloc({required ApiClient apiClient}) : _apiClient = apiClient, super(ContactsInitial()) {
    on<ContactsLoadRequested>(_onLoadRequested);
    on<ContactsSyncRequested>(_onSyncRequested);
    on<ContactAdded>(_onContactAdded);
    on<ContactDeleted>(_onContactDeleted);
  }

  Future<void> _onLoadRequested(ContactsLoadRequested event, Emitter<ContactsState> emit) async {
    emit(ContactsLoading());
    try {
      final response = await _apiClient.get('/api/v1/contacts');
      final contacts = (response.asList).map<ContactItem>((json) => ContactItem(
        userId: json['contact_user_id'] as String? ?? json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? json['contact_user']?['display_name'] as String? ?? 'Без имени',
        username: json['contact_user']?['username'] as String? ?? '',
        avatarUrl: json['contact_user']?['avatar_url'] as String?,
        isOnline: json['contact_user']?['is_online'] as bool? ?? false,
      )).toList();
      emit(ContactsLoaded(contacts: contacts));
    } on CharoApiException catch (e) {
      emit(ContactsError(message: e.message));
    }
  }

  Future<void> _onSyncRequested(ContactsSyncRequested event, Emitter<ContactsState> emit) async {
    await _apiClient.post('/api/v1/contacts/sync');
    add(ContactsLoadRequested());
  }

  Future<void> _onContactAdded(ContactAdded event, Emitter<ContactsState> emit) async {
    await _apiClient.post('/api/v1/contacts', data: {'identifier': event.identifier});
    add(ContactsLoadRequested());
  }

  Future<void> _onContactDeleted(ContactDeleted event, Emitter<ContactsState> emit) async {
    await _apiClient.delete('/api/v1/contacts/${event.userId}');
    final current = state;
    if (current is ContactsLoaded) {
      emit(ContactsLoaded(contacts: current.contacts.where((c) => c.userId != event.userId).toList()));
    }
  }
}
