import 'package:flutter/material.dart';

import '../design/design.dart';

/// Section title with an optional trailing action ("See all"). Announced as a heading.
class OrbiSectionHeader extends StatelessWidget {
  const OrbiSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: t.titleLarge)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: context.metadataStyle),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(AppSize.touch, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
