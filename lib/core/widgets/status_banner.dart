import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = BannerTone.error,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = switch (tone) {
      BannerTone.error => dark ? AppColors.burgundy : AppColors.burgundySoft,
      BannerTone.warning => dark ? AppColors.graphiteRaised : AppColors.ivoryDeep,
      BannerTone.success => dark ? AppColors.graphiteRaised : const Color(0xFFE5F0EA),
    };
    final foreground = switch (tone) {
      BannerTone.error => dark ? AppColors.ivory : AppColors.burgundy,
      _ => Theme.of(context).colorScheme.onSurface,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: Text(message, style: TextStyle(color: foreground))),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

enum BannerTone { error, warning, success }
