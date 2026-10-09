import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/supabase_auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthNotice { none, confirmationSent, resetSent }

class AuthState extends Equatable {
  const AuthState({
    required this.available,
    this.user,
    this.busy = false,
    this.failure,
    this.notice = AuthNotice.none,
  });

  final bool available;
  final AuthUser? user;
  final bool busy;
  final AuthFailureKind? failure;
  final AuthNotice notice;

  bool get signedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? busy,
    AuthFailureKind? failure,
    bool clearFailure = false,
    AuthNotice notice = AuthNotice.none,
  }) => AuthState(
    available: available,
    user: clearUser ? null : (user ?? this.user),
    busy: busy ?? this.busy,
    failure: clearFailure ? null : (failure ?? this.failure),
    notice: notice,
  );

  @override
  List<Object?> get props => [available, user, busy, failure, notice];
}

/// Session state for the whole app. It follows the repository's user stream, so a restored session, a token
/// refresh failure or a sign-out elsewhere is reflected without extra code in the UI.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo)
    : super(AuthState(available: _repo.isAvailable, user: _repo.currentUser)) {
    _sub = _repo.userChanges.listen(
      (u) => emit(state.copyWith(user: u, clearUser: u == null, busy: false)),
    );
  }

  final AuthRepository _repo;
  StreamSubscription<AuthUser?>? _sub;

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

  Future<void> signOut() => _run(() async {
    await _repo.signOut();
    return AuthNotice.none;
  });

  void dismissMessage() =>
      emit(state.copyWith(clearFailure: true, notice: AuthNotice.none));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
