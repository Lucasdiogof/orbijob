import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'focus_ring.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onChanged,
  });

  final bool isFavorite;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final label = isFavorite ? l.favoriteRemove : l.favoriteAdd;
    return Semantics(
      container: true,
      button: true,
      toggled: isFavorite,
      label: label,
      excludeSemantics: true,
      child: FocusRing(
        child: IconButton(
          tooltip: label,
          onPressed: onChanged == null ? null : () => onChanged!(!isFavorite),
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? c.primary : c.ink,
          ),
        ),
      ),
    );
  }
}
