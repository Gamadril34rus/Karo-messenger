import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_db.dart' as db;
import '../../../../core/utils/logger.dart';
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
  final db.AppDatabase _localDb;

  ContactsBloc({required ApiClient apiClient, db.AppDatabase? localDb})
      : _apiClient = apiClient,
        _localDb = localDb ?? db.AppDatabase(),
        super(ContactsInitial()) {
    on<ContactsLoadRequested>(_onLoadRequested);
    on<ContactsSyncRequested>(_onSyncRequested);
    on<ContactAdded>(_onContactAdded);
    on<ContactDeleted>(_onContactDeleted);
  }

  Future<void> _onLoadRequested(ContactsLoadRequested event, Emitter<ContactsState> emit) async {
    emit(ContactsLoading());

    // Try loading from local cache first
    try {
      final cachedContacts = await _localDb.getAllContacts();
      if (cachedContacts.isNotEmpty) {
        emit(ContactsLoaded(contacts: cachedContacts.map(_localContactToItem).toList()));
      }
    } catch (e) {
      logger.w('Contacts local cache load failed: $e');
    }

    // Then fetch from server
    try {
      final response = await _apiClient.get('/api/v1/contacts');
      final contacts = (response.asList).map<ContactItem>((json) => ContactItem(
        userId: json['contact_user_id'] as String? ?? json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? json['contact_user']?['display_name'] as String? ?? 'Без имени',
        username: json['contact_user']?['username'] as String? ?? '',
        avatarUrl: json['contact_user']?['avatar_url'] as String?,
        isOnline: json['contact_user']?['is_online'] as bool? ?? false,
      )).toList();

      // Persist to local DB
      await _persistContacts(contacts);

      emit(ContactsLoaded(contacts: contacts));
    } on CharoApiException catch (e) {
      // If we already have cached data, keep it — don't show error
      if (state is! ContactsLoaded) {
        emit(ContactsError(message: e.message));
      }
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

    // Remove from local DB
    try {
      await _localDb.deleteContact(event.userId);
    } catch (e) {
      logger.w('Failed to delete contact from local DB: $e');
    }

    final current = state;
    if (current is ContactsLoaded) {
      emit(ContactsLoaded(contacts: current.contacts.where((c) => c.userId != event.userId).toList()));
    }
  }

  // ─── Persistence helpers ──────────────────────────────────────────

  Future<void> _persistContacts(List<ContactItem> contacts) async {
    try {
      await _localDb.deleteAllContacts();
      for (final contact in contacts) {
        await _localDb.insertContact(db.LocalContactsCompanion.insert(
          id: contact.userId,
          userId: contact.userId,
          contactUserId: contact.userId,
          displayName: Value(contact.displayName),
        ));
      }
    } catch (e) {
      logger.w('Failed to persist contacts to local DB: $e');
    }
  }

  ContactItem _localContactToItem(db.LocalContact c) {
    return ContactItem(
      userId: c.userId,
      displayName: c.displayName ?? 'Без имени',
      username: '',
      avatarUrl: null,
      isOnline: false,
    );
  }
}
