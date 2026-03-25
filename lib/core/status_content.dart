import 'package:flutter/material.dart';

/// Centered icon + message layout used for empty states and error states.
///
/// Empty states pass the default [iconColor] (`onSurfaceVariant`).
/// Error states override [iconColor] to `colorScheme.error`.
/// An optional [action] widget (e.g. a retry `TextButton`) appears below
/// the message.
class StatusContent extends StatelessWidget {
  const StatusContent({
    required this.icon,
    required this.message,
    this.iconSize = 48,
    this.iconColor,
    this.textStyle,
    this.action,
    this.padding,
    super.key,
  });

  final IconData icon;
  final String message;
  final double iconSize;

  /// Defaults to `Theme.of(context).colorScheme.onSurfaceVariant`.
  final Color? iconColor;

  /// Defaults to `Theme.of(context).textTheme.bodyLarge`.
  final TextStyle? textStyle;

  /// Optional widget rendered below the message (e.g. retry button).
  final Widget? action;

  /// Optional outer padding wrapping the entire content.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = iconColor ?? theme.colorScheme.onSurfaceVariant;
    final resolvedStyle = textStyle ?? theme.textTheme.bodyLarge;

    Widget content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: resolvedColor),
          const SizedBox(height: 16),
          Text(message, style: resolvedStyle),
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}
