import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child, required this.title, this.subtitle});

  final Widget child;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: child,
    );
    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _BrandMark(),
              const SizedBox(height: 28),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!),
              ],
              const SizedBox(height: 24),
              form,
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          const Expanded(child: _BrandPanel()),
          Expanded(
            child: Center(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(40),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!),
                  ],
                  const SizedBox(height: 24),
                  form,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.ink,
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Spacer(),
            _BrandMark(onDark: true),
            SizedBox(height: 16),
            Text(
              'Operations command for wine-led hospitality.',
              style: TextStyle(color: AppColors.ivory, fontSize: 28, height: 1.2),
            ),
            SizedBox(height: 12),
            Text(
              'Cellar, floor, and service in one tenant-isolated workspace.',
              style: TextStyle(color: AppColors.ivoryDeep),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? AppColors.ivory : Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Venue Wrangler', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
        Text('Loungeability LLC', style: TextStyle(color: onDark ? AppColors.brass : AppColors.brassDeep)),
      ],
    );
  }
}
