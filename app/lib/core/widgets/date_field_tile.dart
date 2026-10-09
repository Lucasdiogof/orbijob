import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Optional date picker row (label + value + clear). Used by the experience and education forms.
class DateFieldTile extends StatelessWidget {
  const DateFieldTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      title: Text(label),
      subtitle: Text(
        value == null
            ? l.dateChoose
            : MaterialLocalizations.of(context).formatMediumDate(value!),
      ),
      trailing: value == null || !enabled
          ? const Icon(Icons.event_outlined)
          : IconButton(
              tooltip: l.dateClear,
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ),
      onTap: !enabled
          ? null
          : () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(1950),
                lastDate: DateTime(now.year + 1),
              );
              if (d != null) onChanged(d);
            },
    );
  }
}
