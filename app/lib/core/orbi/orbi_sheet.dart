import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';

/// Opens a modal bottom sheet in the product style (drag handle, rounded top, brand-neutral surface, capped width on wide screens).
/// The builder receives the sheet context; keyboard insets are respected.
Future<T?> showOrbiSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  isDismissible: isDismissible,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: builder(ctx),
  ),
);

/// Sheet layout: a title row with a close button, a scrolling body and an optional fixed footer (the actions stay in reach
/// at any text size). Use inside [showOrbiSheet] or as the body of a side panel.
class OrbiSheetScaffold extends StatelessWidget {
  const OrbiSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.onClose,
    this.maxHeightFactor = 0.9,
    this.showClose = true,
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onClose;
  final double maxHeightFactor;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              0,
              AppSpace.s2,
              AppSpace.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: context.text.titleLarge),
                  ),
                ),
                if (showClose)
                  IconButton(
                    tooltip: l.commonClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed:
                        onClose ?? () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s5,
                AppSpace.s1,
                AppSpace.s5,
                AppSpace.s4,
              ),
              child: body,
            ),
          ),
          if (footer != null)
            // The footer may take at most 45 % of the sheet and scrolls beyond that: with very large text on a small window the
            // title and the actions must never push the sheet past its height.
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH * 0.45),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: footer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled group inside a sheet or side panel.
class OrbiFormSection extends StatelessWidget {
  const OrbiFormSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: context.text.labelMedium!.copyWith(
                color: context.colors.muted,
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}
