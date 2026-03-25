import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared wrapper for modal bottom sheet content.
///
/// Handles keyboard-avoidance padding (viewInsets vs safe-area bottom)
/// and provides the standard horizontal/vertical padding + min-size
/// `Column` layout used by all bottom sheets in the app.
class SheetBody extends StatelessWidget {
  const SheetBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(viewInsets.bottom, padding.bottom);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
