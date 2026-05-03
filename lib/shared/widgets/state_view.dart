import 'package:flutter/material.dart';

class StateView extends StatelessWidget {
  const StateView({
    required this.title,
    required this.body,
    super.key,
    this.actionLabel,
    this.isLoading = false,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final bool isLoading;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: CircularProgressIndicator(),
                ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel ?? 'Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
