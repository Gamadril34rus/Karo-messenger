// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/charo_repository.dart';
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
  final CharoRepository _repository;
  final WsClient _wsClient;

  ProfileBloc({
    required CharoRepository repository,
    required WsClient wsClient,
  })  : _repository = repository,
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
      final profile = await _repository.getMyProfile();
      emit(ProfileLoaded(
        userId: profile.userId,
        username: profile.username,
        displayName: profile.displayName,
        bio: profile.bio,
        avatarUrl: profile.avatarUrl,
        phone: profile.phone,
        email: profile.email,
        isOnline: profile.isOnline,
        lastSeen: profile.lastSeen,
        phoneVisible: profile.phoneVisible,
      ));
    } on CharoApiException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }

  Future<void> _onLoadRequested(ProfileLoadRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final profile = await _repository.getUserProfile(event.userId);
      emit(ProfileLoaded(
        userId: profile.userId,
        username: profile.username,
        displayName: profile.displayName,
        bio: profile.bio,
        avatarUrl: profile.avatarUrl,
        phone: profile.phone,
        email: profile.email,
        isOnline: profile.isOnline,
        lastSeen: profile.lastSeen,
        phoneVisible: profile.phoneVisible,
        isBlocked: profile.isBlocked,
      ));
    } on CharoApiException catch (e) {
      emit(ProfileError(message: e.message));
    }
  }

  Future<void> _onUpdated(ProfileUpdated event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;

    await _repository.updateProfile(
      displayName: event.displayName,
      bio: event.bio,
    );

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

    final newUrl = await _repository.changeAvatar(event.source);
    emit(ProfileLoaded(
      userId: current.userId,
      username: current.username,
      displayName: current.displayName,
      bio: current.bio,
      avatarUrl: newUrl ?? current.avatarUrl,
      phone: current.phone,
      email: current.email,
      isOnline: current.isOnline,
    ));
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
    await _repository.createChat('secret', null, [current.userId]);
  }

  Future<void> _onBlocked(ProfileBlocked event, Emitter<ProfileState> emit) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    await _repository.blockUser(current.userId);
    emit(ProfileLoaded(
      userId: current.userId,
      username: current.username,
      displayName: current.displayName,
      bio: current.bio,
      avatarUrl: current.avatarUrl,
      phone: current.phone,
      email: current.email,
      isOnline: current.isOnline,
      isBlocked: true,
    ));
  }
}
