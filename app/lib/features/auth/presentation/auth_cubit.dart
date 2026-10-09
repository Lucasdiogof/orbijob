import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/supabase_auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthNotice {
  none,
  confirmationSent,
  resetSent,
  passwordChanged,

  /// The session ended without the user asking (token no longer valid, signed out elsewhere).
  sessionExpired,
}

class AuthState extends Equatable {
  const AuthState({
    required this.available,
    this.user,
    this.busy = false,
    this.failure,
    this.notice = AuthNotice.none,
    this.recovering = false,
  });

  final bool available;
  final AuthUser? user;
  final bool busy;
  final AuthFailureKind? failure;
  final AuthNotice notice;

  /// A password-recovery link was opened: the only thing this session may do is choose a new password.
  final bool recovering;

  bool get signedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? busy,
    AuthFailureKind? failure,
    bool clearFailure = false,
    AuthNotice notice = AuthNotice.none,
    bool? recovering,
  }) => AuthState(
    available: available,
    user: clearUser ? null : (user ?? this.user),
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
    notice: notice,
    recovering: recovering ?? this.recovering,
  );

  @override
  List<Object?> get props => [
    available,
    user,
    busy,
    failure,
    notice,
    recovering,
  ];
}

/// Session state for the whole app. It follows the repository's user stream, so a restored session, a token
/// refresh failure or a sign-out elsewhere is reflected without extra code in the UI.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo)
    : super(AuthState(available: _repo.isAvailable, user: _repo.currentUser)) {
    _sub = _repo.userChanges.listen(_onUser, onError: _onStreamError);
    _recovery = _repo.recoveryLinks.listen(
      (_) => emit(state.copyWith(recovering: true)),
      onError: _onStreamError,
    );
  }

  final AuthRepository _repo;
  StreamSubscription<AuthUser?>? _sub;
  StreamSubscription<void>? _recovery;
  bool _signingOut = false;

  void _onUser(AuthUser? u) {
    final wasSignedIn = state.user != null;
    // Signed in -> signed out that the user did not ask for: say so instead of silently dropping to signed out.
    final ended = u == null && wasSignedIn && !_signingOut;
    emit(
      state.copyWith(
        user: u,
        clearUser: u == null,
        busy: false,
        recovering: u == null ? false : state.recovering,
        notice: ended ? AuthNotice.sessionExpired : AuthNotice.none,
      ),
    );
  }

  // Invalid or expired e-mail links surface as errors on the auth stream.
  void _onStreamError(Object e) =>
      emit(state.copyWith(busy: false, failure: mapAuthError(e).kind));

  Future<void> _run(Future<AuthNotice> Function() action) async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      final notice = await action();
      emit(state.copyWith(busy: false, notice: notice));
    } catch (e) {
      emit(state.copyWith(busy: false, failure: mapAuthError(e).kind));
    }
  }

  Future<void> signIn(String email, String password) => _run(() async {
    await _repo.signIn(email: email, password: password);
    return AuthNotice.none;
  });

  Future<void> signUp(String email, String password) => _run(() async {
    final o = await _repo.signUp(email: email, password: password);
    return o == SignUpOutcome.confirmationRequired
        ? AuthNotice.confirmationSent
        : AuthNotice.none;
  });

  Future<void> resetPassword(String email) => _run(() async {
    await _repo.sendPasswordReset(email);
    return AuthNotice.resetSent;
  });

  Future<void> updatePassword(String newPassword) async {
    await _run(() async {
      await _repo.updatePassword(newPassword);
      return AuthNotice.passwordChanged;
    });
    // Success: the recovery session becomes an ordinary one and the new-password screen can close.
    if (state.failure == null) {
      emit(
        state.copyWith(recovering: false, notice: AuthNotice.passwordChanged),
      );
    }
  }

  /// Leaves the recovery screen without choosing a new password: the temporary session is closed.
  Future<void> cancelRecovery() async {
    emit(state.copyWith(recovering: false));
    await signOut();
  }

  Future<void> signOut() async {
    _signingOut = true;
    try {
      await _run(() async {
        await _repo.signOut();
        return AuthNotice.none;
      });
    } finally {
      _signingOut = false;
    }
  }

  void dismissMessage() =>
      emit(state.copyWith(clearFailure: true, notice: AuthNotice.none));

  /// The new-password screen has been shown / handled.
  void recoveryHandled() => emit(state.copyWith(recovering: false));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _recovery?.cancel();
    return super.close();
  }
}
