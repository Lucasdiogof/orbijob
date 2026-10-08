import 'package:flutter/material.dart';

import '../design/design.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.titleLarge),
          ),
        ),
        ?action,
      ],
    );
  }
}
