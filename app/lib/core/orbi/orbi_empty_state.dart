import 'package:flutter/material.dart';

import '../design/design.dart';
import '../motion/motion.dart';
import 'orbi_art.dart';

enum OrbiStateKind { empty, info, error }

/// Empty / info / error state: a small brand composition, title, optional body and optional actions. Scrolls when the
/// space is short (landscape, open keyboard, large text) instead of overflowing.
class OrbiEmptyState extends StatelessWidget {
  const OrbiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.secondaryAction,
    this.kind = OrbiStateKind.empty,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final Widget? secondaryAction;
  final OrbiStateKind kind;

  @override
  Widget build(BuildContext context) {
    final isError = kind == OrbiStateKind.error;
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
                      OrbiArt(icon: icon, error: isError),
                      const SizedBox(height: AppSpace.s5),
                      Reveal(
                        index: 1,
                        child: Text(
                          title,
                          style: context.text.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        Reveal(
                          index: 2,
                          child: Text(
                            body!,
                            style: context.text.bodyMedium!.copyWith(
                              color: context.colors.muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (action != null) ...[
                        const SizedBox(height: AppSpace.s5),
                        Reveal(index: 3, child: action!),
                      ],
                      if (secondaryAction != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        secondaryAction!,
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
