import 'package:flutter/material.dart';

import '../design/design.dart';

enum StateKind { empty, info, error }

/// Empty / info / error state: icon + title + optional body + optional action. Scrolls when space is short
/// (landscape, keyboard open, large text) instead of overflowing.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.kind = StateKind.empty,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final StateKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isError = kind == StateKind.error;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s6),
                child: Semantics(
                  container: true,
                  liveRegion: isError,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: isError
                              ? c.errorContainer
                              : c.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s4),
                          child: Icon(
                            icon,
                            size: 32,
                            color: isError
                                ? c.onErrorContainer
                                : c.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        title,
                        style: context.text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (body != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          body!,
                          style: context.text.bodyMedium!.copyWith(
                            color: c.muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (action != null) ...[
                        const SizedBox(height: AppSpace.s5),
                        action!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
