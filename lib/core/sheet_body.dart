import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kanban_board/core/responsive.dart';

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < kCompactBreakpoint ? 16.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: horizontalPad,
        right: horizontalPad,
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

/// Centralized bottom sheet launcher with responsive width constraint.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
    builder: (_) => child,
  );
}
