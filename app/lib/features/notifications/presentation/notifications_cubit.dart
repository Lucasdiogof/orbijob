import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../domain/notifications_repository.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const [],
    this.alertsEnabled = true,
    this.busy = false,
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;
  final List<AppNotification> items;

  /// The person's own switch (`settings.notifications.enabled`); the database honours it when it runs.
  final bool alertsEnabled;
  final bool busy;
  final DataFailureKind? actionFailure;
  final int actionTick;

  int get unread => items.where((n) => n.unread).length;

  NotificationsState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    List<AppNotification>? items,
    bool? alertsEnabled,
    bool? busy,
    DataFailureKind? actionFailure,
  }) => NotificationsState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    busy: busy ?? this.busy,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items,
    alertsEnabled,
    busy,
    actionFailure,
    actionTick,
  ];
}

/// The notification centre: the jobs the database announced, newest first, and the switch that turns alerts off. Nothing here creates a
/// notification; it reads what the hourly run wrote. New ones are picked up when the app comes back to the foreground and, while it is open, every
/// few minutes ([refreshEvery]; null = never, used by tests).
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._repo,
    this._settings, {
    this.refreshEvery = const Duration(minutes: 5),
  }) : super(const NotificationsState());

  final NotificationsRepository? _repo;
  final AccountSettingsRepository? _settings;
  final Duration? refreshEvery;
  Timer? _timer;

  Future<void> load() async {
    final repo = _repo;
    if (repo == null) {
      return emit(
        state.copyWith(
          status: LoadStatus.failure,
          failure: DataFailureKind.notConfigured,
        ),
      );
    }
    emit(state.copyWith(status: LoadStatus.loading, clearFailure: true));
    await _fetch(repo);
    final every = refreshEvery;
    if (every != null && state.status == LoadStatus.ready) {
      _timer ??= Timer.periodic(every, (_) => refresh());
    }
  }

  /// Reads again without showing a spinner; a failure keeps what is on screen.
  Future<void> refresh() async {
    final repo = _repo;
    if (repo == null || state.status != LoadStatus.ready) return;
    try {
      final items = await repo.list();
      emit(state.copyWith(items: items));
    } catch (_) {
      // quiet: the list on screen is still true
    }
  }

  Future<void> _fetch(NotificationsRepository repo) async {
    try {
      final items = await repo.list();
      var enabled = true;
      try {
        final s = _settings;
        if (s != null) enabled = alertsEnabledIn(await s.load());
      } catch (_) {
        // the switch is optional information; the list is what matters
      }
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          items: items,
          alertsEnabled: enabled,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<void> markRead(AppNotification n) async {
    final repo = _repo;
    if (repo == null || !n.unread) return;
    final now = DateTime.now().toUtc();
    final before = state.items;
    emit(
      state.copyWith(
        items: [for (final e in before) e.id == n.id ? e.markedRead(now) : e],
      ),
    );
    try {
      await repo.markRead([n.id]);
    } catch (e) {
      emit(state.copyWith(items: before, actionFailure: mapDataError(e)));
    }
  }

  Future<void> markAllRead() async {
    final repo = _repo;
    if (repo == null || state.unread == 0 || state.busy) return;
    final now = DateTime.now().toUtc();
    final before = state.items;
    emit(
      state.copyWith(
        busy: true,
        items: [for (final e in before) e.markedRead(now)],
      ),
    );
    try {
      await repo.markAllRead();
      emit(state.copyWith(busy: false));
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          items: before,
          actionFailure: mapDataError(e),
        ),
      );
    }
  }

  Future<void> dismiss(AppNotification n) async {
    final repo = _repo;
    if (repo == null) return;
    final before = state.items;
    emit(
      state.copyWith(
        items: [
          for (final e in before)
            if (e.id != n.id) e,
        ],
      ),
    );
    try {
      await repo.dismiss(n.id);
    } catch (e) {
      emit(state.copyWith(items: before, actionFailure: mapDataError(e)));
    }
  }

  Future<void> dismissAll() async {
    final repo = _repo;
    if (repo == null || state.items.isEmpty || state.busy) return;
    final before = state.items;
    emit(state.copyWith(busy: true, items: const []));
    try {
      await repo.dismissAll();
      emit(state.copyWith(busy: false));
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          items: before,
          actionFailure: mapDataError(e),
        ),
      );
    }
  }

  /// Turns alerts on or off for the whole account. Returns whether it was stored.
  Future<bool> setAlertsEnabled(bool on) async {
    final s = _settings;
    if (s == null) {
      emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
      return false;
    }
    final before = state.alertsEnabled;
    emit(state.copyWith(alertsEnabled: on, busy: true));
    try {
      await s.setKey('notifications', {'enabled': on});
      emit(state.copyWith(busy: false));
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          alertsEnabled: before,
          actionFailure: mapDataError(e),
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
