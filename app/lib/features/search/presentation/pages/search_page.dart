import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/search_cubit.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onSubmitted: (q) => context.read<SearchCubit>().search(q),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, s) => switch (s) {
                      SearchIdle() => _Message(
                        Icons.travel_explore,
                        l.emptyTitle,
                        l.emptyBody,
                      ),
                      SearchLoading() => Center(
                        child: Semantics(
                          label: l.loading,
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                      SearchNoSource() => _Message(
                        Icons.public_off,
                        l.noSourceTitle,
                        l.noSourceBody,
                      ),
                      SearchFailure(:final query) => _Message(
                        Icons.error_outline,
                        l.errorTitle,
                        '',
                        action: TextButton(
                          onPressed: () =>
                              context.read<SearchCubit>().search(query),
                          child: Text(l.retry),
                        ),
                      ),
                      SearchSuccess(:final jobs) => ListView(
                        children: [
                          for (final j in jobs)
                            Card(
                              child: ListTile(
                                title: Text(j.title),
                                subtitle: Text(j.company),
                              ),
                            ),
                        ],
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.icon, this.title, this.body, {this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
          ?action,
        ],
      ),
    );
  }
}
