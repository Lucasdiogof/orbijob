import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';

/// Search input: leading icon, clear button, "search" keyboard action. With [readOnly] + [onTap] it works as an
/// entry point that opens the real search (Home).
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
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
    final colors = context.colors;
    return Semantics(
      container: true,
      label: l.searchLabel,
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
          prefixIcon: Icon(Icons.search, color: colors.muted),
          suffixIcon: (!widget.readOnly && _c.text.isNotEmpty)
              ? IconButton(
                  tooltip: l.searchClear,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _c.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}
