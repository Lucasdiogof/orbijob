import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_assets.dart';

/// Horizontal logo (symbol + ORBIJOB). Picks the light/dark artwork from the active theme.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 28, this.brightness});

  final double height;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return SvgPicture.asset(
      AppAssets.logoHorizontal(b),
      height: height,
      semanticsLabel: 'OrbiJob',
    );
  }
}

/// Isolated symbol (two opposing arcs + central point).
class BrandSymbol extends StatelessWidget {
  const BrandSymbol({
    super.key,
    this.size = 32,
    this.brightness,
    this.semanticLabel = 'OrbiJob',
  });

  final double size;
  final Brightness? brightness;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return SvgPicture.asset(
      AppAssets.symbol(b),
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
    );
  }
}
