import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';

/// Temporary page used while a route's screen is being built.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.title, {super.key, this.tab = false, this.showBell = true});

  final String title;
  final bool tab;
  final bool showBell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (tab) TabHeader(showBell: showBell) else const DetailHeader(),
          Expanded(child: Center(child: Text(title, style: AppTypography.titleMedium))),
        ],
      ),
    );
  }
}
