import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/ws_client.dart';

// ─── Events ────────────────────────────────────────────────────────

sealed class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ProfileMeRequested extends ProfileEvent {}

final class ProfileLoadRequested extends ProfileEvent {
  final String userId;
  ProfileLoadRequested({required this.userId});
  @override
  List<Object?> get props => [userId];
}

final class ProfileUpdated extends ProfileEvent {
  final String? displayName;
  final String? bio;
  ProfileUpdated({this.displayName, this.bio});
  @override
  List<Object?> get props => [displayName, bio];
}

final class ProfileAvatarChanged extends ProfileEvent {
  final String source; // camera, gallery, ai, remove
  ProfileAvatarChanged({required this.source});
  @override
  List<Object?> get props => [source];
}

final class ProfileCallInitiated extends ProfileEvent {
  final bool isVideo;
  ProfileCallInitiated({required this.isVideo});
  @override
  List<Object?> get props => [isVideo];
}

final class ProfileMuteToggled extends ProfileEvent {}

final class ProfileSecretChatRequested extends ProfileEvent {}

final class ProfileBlocked extends ProfileEvent {}

// ─── States ────────────────────────────────────────────────────────

sealed class ProfileState extends Equatable {
  @override
  List<Object?> get props => [];
}

final class ProfileInitial extends ProfileState {}

final class ProfileLoading extends ProfileState {}

final class ProfileLoaded extends ProfileState {
  final String userId;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool phoneVisible;
  final bool isBlocked;

  ProfileLoaded({
    required this.userId,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.phone,
    this.email,
    this.isOnline = false,
    this.lastSeen,
    this.phoneVisible = true,
    this.isBlocked = false,
  });

  @override
  List<Object?> get props => [userId, username, displayName, bio, avatarUrl, phone, email, isOnline, lastSeen, phoneVisible, isBlocked];
}

final class ProfileError extends ProfileState {
  final String message;
  ProfileError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ApiClient _apiClient;
  final SecureStorageHelper _secureStorage;
  final WsClient _wsClient;

  ProfileBloc({
    required ApiClient apiClient,
    required SecureStorageHelper secureStorage,
    required WsClient wsClient,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _wsClient = wsClient,
        super(ProfileInitial()) {
    on<ProfileMeRequested>(_onMeRequested);
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdated>(_onUpdated);
    on<ProfileAvatarChanged>(_onAvatarChanged);
    on<ProfileCallInitiated>(_onCallInitiated);
    on<ProfileMuteToggled>(_onMuteToggled);
    on<ProfileSecretChatRequested>(_onSecretChatRequested);
    on<ProfileBlocked>(_onBlocked);
  }

  Future<void> _onMeRequested(ProfileMeRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final response = await _apiClient.get('/api/v1/users/me');
      final data = response.asMap;
      emit(ProfileLoaded(
        userId: data['id'] as String,
        username: data['username'] as String,
        displayName: data['display_name'] as String?,
        bio: data['bio'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        isOnline: data['is_online'] as bool? ?? true,
        lastSeen: data['last_seen'] != null ? DateTime.parse(data['last_seen'] as String) : null,
        phoneVisible: data['phone_visible'] as bool? ?? true,
      ));
    } on CharoApiException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }

  Future<void> _onLoadRequested(ProfileLoadRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final response = await _apiClient.get('/api/v1/users/${event.userId}');
      final data = response.asMap;
      emit(ProfileLoaded(
        userId: data['id'] as String,
        username: data['username'] as String,
        displayName: data['display_name'] as String?,
        bio: data['bio'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        isOnline: data['is_online'] as bool? ?? false,
        lastSeen: data['last_seen'] != null ? DateTime.parse(data['last_seen'] as String) : null,
        phoneVisible: data['phone_visible'] as bool? ?? false,
      ));
    } on CharoApiException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }

  Future<void> _onUpdated(ProfileUpdated event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;

    final data = <String, dynamic>{};
    if (event.displayName != null) data['display_name'] = event.displayName;
    if (event.bio != null) data['bio'] = event.bio;

    await _apiClient.patch('/api/v1/users/me', data: data);

    emit(ProfileLoaded(
      userId: current.userId,
      username: current.username,
      displayName: event.displayName ?? current.displayName,
      bio: event.bio ?? current.bio,
      avatarUrl: current.avatarUrl,
      phone: current.phone,
      email: current.email,
      isOnline: current.isOnline,
    ));
  }

  Future<void> _onAvatarChanged(ProfileAvatarChanged event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;

    if (event.source == 'remove') {
      await _apiClient.patch('/api/v1/users/me', data: {'avatar_url': null});
      emit(ProfileLoaded(
        userId: current.userId, username: current.username,
        displayName: current.displayName, bio: current.bio,
        phone: current.phone, email: current.email,
        isOnline: current.isOnline,
      ));
    } else if (event.source == 'ai') {
      final response = await _apiClient.post('/api/v1/ai/generate-avatar', data: {'prompt': 'avatar'});
      final url = response.asMap['url'] as String?;
      emit(ProfileLoaded(
        userId: current.userId, username: current.username,
        displayName: current.displayName, bio: current.bio,
        avatarUrl: url, phone: current.phone, email: current.email,
        isOnline: current.isOnline,
      ));
    } else {
      // camera / gallery — отправляем multipart
      final response = await _apiClient.patch('/api/v1/users/me/avatar', data: {'source': event.source});
      final url = response.asMap['avatar_url'] as String?;
      emit(ProfileLoaded(
        userId: current.userId, username: current.username,
        displayName: current.displayName, bio: current.bio,
        avatarUrl: url, phone: current.phone, email: current.email,
        isOnline: current.isOnline,
      ));
    }
  }

  void _onCallInitiated(ProfileCallInitiated event, Emitter<ProfileState> emit) {
    final current = state;
    if (current is! ProfileLoaded) return;
    _wsClient.send('call.initiate', {
      'targetUserId': current.userId,
      'type': event.isVideo ? 'video' : 'voice',
    });
  }

  Future<void> _onMuteToggled(ProfileMuteToggled event, Emitter<ProfileState> emit) async {
    // Тoggled mute для конкретного пользователя
  }

  Future<void> _onSecretChatRequested(ProfileSecretChatRequested event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    await _apiClient.post('/api/v1/chats', data: {
      'type': 'secret',
      'targetUserId': current.userId,
    });
  }

  Future<void> _onBlocked(ProfileBlocked event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    await _apiClient.post('/api/v1/contacts', data: {
      'contactUserId': current.userId,
      'isBlocked': true,
    });
  }
}
