import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'orbi_form.dart';

/// Labelled text input. The label sits above the field (always visible, never a floating hint that disappears),
/// the helper or error text below, and the whole thing is one semantic group.
class OrbiTextField extends StatelessWidget {
  const OrbiTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.suffix,
    this.inputFormatters,
    this.autofocus = false,
    this.validator,
    this.optional = false,
    this.textCapitalization = TextCapitalization.none,
    this.textStyle,
    this.textAlign = TextAlign.start,
  });

  /// Overrides the input text style (a code field uses a wide-tracked technical style); presentation only.
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final String label;
  final bool optional;
  final TextCapitalization textCapitalization;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiFieldLabel(label, optional: optional),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          validator: validator,
          style: textStyle ?? context.text.bodyLarge,
          textAlign: textAlign,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            errorText: errorText,
            errorMaxLines: 3,
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Search field: a rounded, filled bar with a leading icon and a clear button. With [readOnly] + [onTap] it is an entry point
/// that opens the real search (Home). A [trailing] widget (the filters button) sits inside the bar.
class OrbiSearchField extends StatefulWidget {
  const OrbiSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.trailing,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final Widget? trailing;

  @override
  State<OrbiSearchField> createState() => _OrbiSearchFieldState();
}

class _OrbiSearchFieldState extends State<OrbiSearchField> {
  late final TextEditingController _own = TextEditingController();
  TextEditingController get _c => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onText);
  }

  @override
  void dispose() {
    _c.removeListener(_onText);
    _own.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final showClear = !widget.readOnly && _c.text.isNotEmpty;
    return Semantics(
      container: true,
      label: l.searchLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.container,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                focusNode: widget.focusNode,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.hint ?? l.searchHint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, color: c.muted),
                  suffixIcon: showClear
                      ? IconButton(
                          tooltip: l.searchClear,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _c.clear();
                            widget.onChanged?.call('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              SizedBox(
                height: 24,
                child: VerticalDivider(color: c.line, width: AppSpace.s2),
              ),
              widget.trailing!,
              const SizedBox(width: AppSpace.s1),
            ],
          ],
        ),
      ),
    );
  }
}
