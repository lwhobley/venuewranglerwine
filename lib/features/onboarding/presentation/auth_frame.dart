import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/hospitality_design.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
  });
  final Widget child;
  final String title;
  final String? subtitle;

  Widget _form(BuildContext context) => WelcomeReveal(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 28),
          child,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _BrandMark(),
              const SizedBox(height: 24),
              const HospitalityHero(
                title: 'Every detail.\nEvery guest.',
                subtitle: 'A little more harmony in every service.',
                eyebrow: 'WELCOME TO YOUR VENUE',
              ),
              const SizedBox(height: 32),
              Align(alignment: Alignment.centerLeft, child: _form(context)),
              const SizedBox(height: 24),
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
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: 48),
                      _form(context),
                    ],
                  ),
                ),
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        hospitalityImage,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.ink.withValues(alpha: 0.12),
              AppColors.ink.withValues(alpha: 0.88),
            ],
          ),
        ),
      ),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.sizeOf(context).height - 120).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.wine_bar_outlined,
                  color: AppColors.ivory,
                  size: 42,
                ),
                const SizedBox(height: 24),
                Text(
                  'The art of\na great evening.',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(color: AppColors.ivory, height: 1.15),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your cellar. Your floor. Your people.\nBeautifully in sync.',
                  style: TextStyle(
                    color: AppColors.ivoryDeep,
                    fontSize: 18,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'VENUE WRANGLER',
                  style: TextStyle(
                    color: AppColors.ivoryDeep,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.wine_bar_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Venue Wrangler',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'HOSPITALITY, IN HARMONY',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.3),
            ),
          ],
        ),
      ),
    ],
  );
}
