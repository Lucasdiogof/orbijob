import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'orbi_buttons.dart';
import 'orbi_feedback.dart';

/// A form screen: title, centred scrolling column, and a save bar that stays above the keyboard and the safe area, so the
/// action is always reachable. When [dirty] is true, leaving (back button, swipe, system back) asks before discarding.
class OrbiFormPage extends StatelessWidget {
  const OrbiFormPage({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.saving,
    required this.onSave,
    this.dirty = false,
    this.saveLabel,
    this.maxWidth = 640,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final bool saving;
  final VoidCallback onSave;
  final bool dirty;
  final String? saveLabel;
  final double maxWidth;

  Future<void> _confirmLeave(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final leave = await showOrbiConfirm(
      context,
      title: l.formDiscardTitle,
      message: l.formDiscardBody,
      confirmLabel: l.formDiscard,
      cancelLabel: l.formKeepEditing,
      destructive: true,
    );
    if (leave) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return PopScope(
      canPop: !dirty || saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpace.s4),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Align(
              heightFactor: 1,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: OrbiPrimaryButton(
                    label: saveLabel ?? l.commonSave,
                    expand: true,
                    loading: saving,
                    onPressed: saving ? null : onSave,
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

/// Label above a field, with a muted "Optional" marker, shared by the custom fields below.
class OrbiFieldLabel extends StatelessWidget {
  const OrbiFieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (optional)
              TextSpan(
                text: ' · ${l.commonOptional}',
                style: context.text.labelMedium!.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        style: context.text.labelMedium!.copyWith(color: c.ink),
      ),
    );
  }
}

/// Date field: looks like the text fields, opens the platform date picker, can be cleared. [errorText] shows under it.
class OrbiDateField extends StatelessWidget {
  const OrbiDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.optional = true,
    this.errorText,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final bool optional;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(now.year + 1),
    );
    if (d != null) onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final text = value == null
        ? l.dateChoose
        : MaterialLocalizations.of(context).formatMediumDate(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiFieldLabel(label, optional: optional),
        Semantics(
          button: true,
          enabled: enabled,
          label: '$label, $text',
          excludeSemantics: true,
          onTap: enabled ? () => _pick(context) : null,
          child: Material(
            color: enabled ? c.container : c.container.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: enabled ? () => _pick(context) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: context.text.bodyLarge!.copyWith(
                            color: value == null || !enabled
                                ? c.inputPlaceholder
                                : c.ink,
                          ),
                        ),
                      ),
                      if (value != null && enabled)
                        IconButton(
                          tooltip: l.dateClear,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => onChanged(null),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(AppSpace.s3),
                          child: Icon(Icons.event_outlined, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              errorText!,
              style: context.text.bodySmall!.copyWith(color: c.error),
            ),
          ),
      ],
    );
  }
}

/// Single-choice field with the label above, same look as the text fields.
class OrbiDropdownField<T> extends StatelessWidget {
  const OrbiDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.optional = false,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool optional;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OrbiFieldLabel(label, optional: optional),
      Semantics(
        label: label,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: enabled && onChanged != null
              ? (v) {
                  if (v is T) onChanged!(v);
                }
              : null,
        ),
      ),
    ],
  );
}

/// A list of short tags (skills): chips with a remove button, and a field with an add button. Enter adds too.
class OrbiTagInput extends StatefulWidget {
  const OrbiTagInput({
    super.key,
    required this.label,
    required this.addLabel,
    required this.removeLabel,
    required this.tags,
    required this.onChanged,
    this.helper,
    this.maxTags = 200,
    this.maxLength = 80,
  });

  final String label;
  final String addLabel;
  final String Function(String tag) removeLabel;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String? helper;
  final int maxTags;
  final int maxLength;

  @override
  State<OrbiTagInput> createState() => OrbiTagInputState();
}

class OrbiTagInputState extends State<OrbiTagInput> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Adds the pending text (called on Enter, on the + button and when the form is saved).
  void commit() {
    final v = _input.text.trim();
    if (v.isEmpty || v.length > widget.maxLength) return;
    if (widget.tags.any((s) => s.toLowerCase() == v.toLowerCase())) {
      _input.clear();
      return;
    }
    if (widget.tags.length >= widget.maxTags) return;
    widget.onChanged([...widget.tags, v]);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiFieldLabel(widget.label, optional: true),
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final s in widget.tags)
                InputChip(
                  label: Text(s),
                  backgroundColor: c.container,
                  side: BorderSide.none,
                  deleteButtonTooltipMessage: widget.removeLabel(s),
                  onDeleted: () => widget.onChanged([
                    for (final e in widget.tags)
                      if (e != s) e,
                  ]),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: widget.addLabel,
                  helperText: widget.helper,
                  helperMaxLines: 2,
                ),
                onSubmitted: (_) => commit(),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            IconButton.filledTonal(
              tooltip: widget.addLabel,
              icon: const Icon(Icons.add_rounded),
              onPressed: commit,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Saved" feedback after a form closes: shown on the screen underneath, so it survives the pop.
void showSavedFeedback(ScaffoldMessengerState? messenger, String message) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
