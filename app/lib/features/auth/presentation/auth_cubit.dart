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

  /// A recovery code (or link) was accepted: the session that exists now is the TEMPORARY recovery session. The only thing it may do is
  /// choose a new password; it is not a sign-in (no Home, no account data) until the password is saved, and it ends with a sign-out.
  final bool recovering;

  /// Signed in to use the account: a recovery session does not count.
  bool get signedIn => user != null && !recovering;

  /// The person whose account screens and data may be shown (null while recovering).
  AuthUser? get accountUser => recovering ? null : user;

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

/// Remembers on the device that a recovery session is waiting for its new password, so a restart of the app in the middle of the recovery
/// returns to the new-password screen instead of treating the temporary session as a sign-in.
abstract class RecoveryMarker {
  String? read();
  Future<void> write(String? userId);
}

/// Session state for the whole app. It follows the repository's user stream, so a restored session, a token
/// refresh failure or a sign-out elsewhere is reflected without extra code in the UI.
class AuthCubit extends Cubit<AuthState> {
  /// Device clean-up that needs the session (the push token row), run before it ends.
  final Future<void> Function()? beforeSignOut;

  /// Device clean-up after the account was deleted (recent searches, translation cache): nothing of the person may stay on the phone.
  final Future<void> Function()? afterAccountDeleted;

  AuthCubit(
    this._repo, {
    this.beforeSignOut,
    this.afterAccountDeleted,
    RecoveryMarker? recoveryMarker,
  }) : _marker = recoveryMarker,
       super(
         AuthState(
           available: _repo.isAvailable,
           user: _repo.currentUser,
           // the app was closed while a recovery session waited for its new password: it is still not a sign-in
           recovering:
               _repo.currentUser != null &&
               recoveryMarker?.read() == _repo.currentUser!.id,
         ),
       ) {
    _sub = _repo.userChanges.listen(_onUser, onError: _onStreamError);
    _recovery = _repo.recoveryLinks.listen(
      (_) => _enterRecovery(),
      onError: _onStreamError,
    );
  }

  final RecoveryMarker? _marker;

  /// Between the code being sent to the server and its answer: a session that appears now IS the recovery session.
  bool _verifyingCode = false;

  void _enterRecovery() {
    final u = _repo.currentUser ?? state.user;
    emit(state.copyWith(user: u, recovering: true));
    _marker?.write(u?.id);
  }

  void _leaveRecovery() {
    if (state.recovering) emit(state.copyWith(recovering: false));
    _marker?.write(null);
  }

  final AuthRepository _repo;
  StreamSubscription<AuthUser?>? _sub;
  StreamSubscription<void>? _recovery;
  bool _signingOut = false;

  void _onUser(AuthUser? u) {
    final wasSignedIn = state.signedIn;
    // Signed in -> signed out that the user did not ask for: say so instead of silently dropping to signed out.
    final ended = u == null && wasSignedIn && !_signingOut;
    // The session created by verifyOTP(recovery) arrives here as an ordinary sign-in, possibly before verifyRecoveryCode returns: it is the
    // recovery session. A session of ANOTHER person, or no session, ends any recovery.
    final recovering = u == null
        ? false
        : _verifyingCode || (state.recovering && state.user?.id == u.id);
    if (!recovering) _marker?.write(null);
    emit(
      state.copyWith(
        user: u,
        clearUser: u == null,
        busy: _verifyingCode ? state.busy : false,
        // A new session supersedes an old link error (e.g. a duplicate callback that failed after the first worked).
        clearFailure: u != null,
        recovering: recovering,
        notice: ended ? AuthNotice.sessionExpired : AuthNotice.none,
      ),
    );
    if (recovering) _marker?.write(u.id);
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

  /// Checks the 6-digit code; success opens the temporary recovery session (the new-password screen follows).
  Future<void> verifyRecoveryCode(String email, String code) async {
    _verifyingCode = true;
    try {
      await _run(() async {
        await _repo.verifyRecoveryCode(email: email, code: code);
        return AuthNotice.none;
      });
    } finally {
      _verifyingCode = false;
    }
    // the session exists as soon as verifyOTP returns, even when its SIGNED_IN event has not arrived yet
    if (state.failure == null && (_repo.currentUser ?? state.user) != null) {
      _enterRecovery();
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _run(() async {
      await _repo.updatePassword(newPassword);
      return AuthNotice.passwordChanged;
    });
    // Success: the recovery is over. Its temporary session is closed and the person signs in with the new password (the login screen
    // opens with the confirmation). A failure keeps the recovery session so the person can try again.
    if (state.failure != null) return;
    _marker?.write(null);
    _signingOut = true;
    try {
      try {
        await _repo.signOut();
      } catch (_) {}
      emit(
        state.copyWith(
          clearUser: true,
          recovering: false,
          busy: false,
          notice: AuthNotice.passwordChanged,
        ),
      );
    } finally {
      _signingOut = false;
    }
  }

  /// Leaves the recovery screen without choosing a new password: the temporary session is closed.
  Future<void> cancelRecovery() async {
    _leaveRecovery();
    await signOut();
  }

  Future<void> signOut() async {
    _leaveRecovery();
    _signingOut = true;
    try {
      await _run(() async {
        // device clean-up that needs the session (push token row) happens before it ends; never blocks the sign-out
        try {
          await beforeSignOut?.call();
        } catch (_) {}
        await _repo.signOut();
        return AuthNotice.none;
      });
    } finally {
      _signingOut = false;
    }
  }

  /// Permanent deletion; [password] is checked again by the server. The account and its data are gone on success, but the person stays
  /// "signed in" on screen until [finishAccountDeletion]: the confirmation must be shown before the account scope is torn down (a snack
  /// bar shown after that is lost). A failure keeps everything and sets [AuthState.failure].
  Future<void> deleteAccount(String password) async {
    _leaveRecovery();
    await _run(() async {
      await _repo.deleteAccount(password);
      for (final cleanup in [beforeSignOut, afterAccountDeleted]) {
        try {
          await cleanup?.call();
        } catch (_) {}
      }
      return AuthNotice.none;
    });
  }

  /// Ends the session of the deleted account on this device (the server no longer knows it, so a refusal is ignored).
  Future<void> finishAccountDeletion() async {
    _leaveRecovery();
    _signingOut = true;
    try {
      try {
        await _repo.signOut();
      } catch (_) {}
      if (state.user != null) {
        emit(state.copyWith(clearUser: true, busy: false, recovering: false));
      }
    } finally {
      _signingOut = false;
    }
  }

  void dismissMessage() =>
      emit(state.copyWith(clearFailure: true, notice: AuthNotice.none));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _recovery?.cancel();
    return super.close();
  }
}
