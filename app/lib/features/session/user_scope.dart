import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/locale_cubit.dart';
import '../../core/theme_cubit.dart';
import '../applications/applications_cubit.dart';
import '../auth/presentation/auth_cubit.dart';
import '../favorites/favorites_cubit.dart';
import '../home/recent_searches_cubit.dart';
import '../preferences/presentation/preferences_cubit.dart';
import '../hidden/presentation/hidden_jobs_cubit.dart';
import '../notifications/presentation/notifications_cubit.dart';
import '../searches/presentation/saved_searches_cubit.dart';
import '../profile/presentation/profile_cubit.dart';
import '../../core/data/load_status.dart';
import '../../core/widgets/data_state_view.dart';

/// Owns everything that belongs to ONE account: favourites, profile, applications, preferences and saved searches.
/// It is rebuilt (new Cubits, new requests, nothing carried over) whenever the signed-in user changes, so after a
/// sign-out or a switch from account A to account B no cached data of A can be shown to B.
///
/// While nobody is signed in the Cubits report "sign in" without sending a request: the repositories refuse before
/// reaching the network.
class UserScope extends StatelessWidget {
  const UserScope({super.key, required this.child, required this.navigator});
  final Widget child;

  /// Screens opened by one account (profile, forms, details) hold that account's Cubits: they are closed when the
  /// user changes, so none of them may stay on the stack.
  final GlobalKey<NavigatorState> navigator;

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
    listenWhen: (a, b) => a.user?.id != b.user?.id,
    listener: (_, _) => navigator.currentState?.popUntil((r) => r.isFirst),
    child: BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.user?.id != b.user?.id,
      builder: (context, auth) => KeyedSubtree(
        key: ValueKey(auth.user?.id ?? 'anonymous'),
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<FavoritesCubit>()..load()),
            BlocProvider(create: (_) => sl<ProfileCubit>()..load()),
            BlocProvider(create: (_) => sl<ApplicationsCubit>()..load()),
            BlocProvider(create: (_) => sl<PreferencesCubit>()..load()),
            BlocProvider(create: (_) => sl<SavedSearchesCubit>()..load()),
            BlocProvider(create: (_) => sl<NotificationsCubit>()..load()),
            BlocProvider(create: (_) => sl<HiddenJobsCubit>()..load()),
          ],
          child: _ScopeEffects(userId: auth.user?.id, child: child),
        ),
      ),
    ),
  );
}

class _ScopeEffects extends StatefulWidget {
  const _ScopeEffects({required this.child, this.userId});
  final Widget child;
  final String? userId;
  @override
  State<_ScopeEffects> createState() => _ScopeEffectsState();
}

class _ScopeEffectsState extends State<_ScopeEffects> {
  @override
  void initState() {
    super.initState();
    // Recent searches are a device-level convenience kept per account: each person sees only their own.
    context.read<RecentSearchesCubit>().useScope(widget.userId);
  }

  static ThemeMode _mode(String t) => switch (t) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<HiddenJobsCubit, HiddenJobsState>(
        listenWhen: (a, b) => a.actionTick != b.actionTick,
        // The card that asked may be gone by now (a hidden job leaves the list), so the refusal is reported from the scope.
        listener: (context, s) {
          if (s.actionFailure != null) {
            showDataFailure(context, s.actionFailure!);
          }
        },
      ),
    ],
    child: BlocListener<PreferencesCubit, PreferencesState>(
      // Once, when the account's preferences arrive: apply theme and language on this device.
      listenWhen: (a, b) =>
          a.status != LoadStatus.ready && b.status == LoadStatus.ready,
      listener: (context, s) {
        context.read<ThemeCubit>().select(_mode(s.prefs.theme));
        context.read<LocaleCubit>().select(s.prefs.locale);
      },
      child: widget.child,
    ),
  );
}
