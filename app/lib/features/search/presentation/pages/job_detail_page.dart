import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/job_posting.dart';
import '../widgets/job_detail_view.dart';

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({
    super.key,
    required this.scored,
    this.onOpenApplication,
  });

  final ScoredJob scored;
  final VoidCallback? onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.jobDetailTitle),
        leading: const BackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: context.colors.divider, height: 1),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: JobDetailView(
            scored: scored,
            onOpenApplication: onOpenApplication,
          ),
        ),
      ),
    );
  }
}
