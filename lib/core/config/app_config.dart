import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.requireEmailVerification,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool requireEmailVerification;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      requireEmailVerification: const bool.fromEnvironment(
        'REQUIRE_EMAIL_VERIFICATION',
        defaultValue: true,
      ),
    );
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final startupErrorProvider = Provider<Object?>((ref) => null);
