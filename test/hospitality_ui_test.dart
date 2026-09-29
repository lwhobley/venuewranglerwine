import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:venue_wrangler/app/theme/app_theme.dart';
import 'package:venue_wrangler/features/dashboard/presentation/workspace_pages.dart';
import 'package:venue_wrangler/features/onboarding/application/tenant_controller.dart';
import 'package:venue_wrangler/features/onboarding/domain/tenant_models.dart';
import 'package:venue_wrangler/features/onboarding/domain/tenant_session.dart';
import 'package:venue_wrangler/features/onboarding/presentation/auth_frame.dart';
import 'package:venue_wrangler/features/onboarding/presentation/credential_form.dart';

TenantSession fixture(String role) => TenantSession(
  userId: 'preview-user',
  memberships: [
    MembershipRecord(
      id: 'member',
      organizationId: 'org',
      userId: 'preview-user',
      roleKey: role,
      status: 'active',
    ),
  ],
  organizations: const [
    Organization(id: 'org', name: 'The Olive Room', slug: 'olive-room'),
  ],
  venues: const [
    Venue(
      id: 'venue',
      organizationId: 'org',
      name: 'The Olive Room',
      slug: 'olive-room',
      timezone: 'America/Chicago',
      currencyCode: 'USD',
      serviceStyle: 'restaurant',
      status: 'active',
    ),
  ],
  invites: [],
  joinRequests: [],
  auditEvents: [],
);

class PreviewTenant extends TenantController {
  PreviewTenant(this.session);
  final TenantSession session;
  @override
  Future<TenantSession> build() async => session;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['VW_UI_PREVIEW_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final family in ['Fraunces', 'SourceSans3']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(360, 800), const Size(1200, 850)]) {
    testWidgets(
      'sign-in is scrollable at $size with enlarged text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: key,
              child: AuthFrame(
                title: 'Sign in',
                subtitle: 'Welcome back to your venue.',
                child: CredentialForm(
                  primaryLabel: 'Sign in',
                  onSubmit: (_, _, _) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Sign in'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'phone navigation keeps all owner workspaces reachable (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final router = GoRouter(
          initialLocation: '/app/home',
          routes: [
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/app/home',
                  builder: (context, state) => const HomePage(),
                ),
                for (final path in [
                  'host',
                  'cellar',
                  'people',
                  'business',
                  'team',
                  'profile',
                ])
                  GoRoute(
                    path: '/app/$path',
                    builder: (context, state) =>
                        Center(child: Text('Selected $path')),
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tenantControllerProvider.overrideWith(
                () => PreviewTenant(fixture('organization_owner')),
              ),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        await capture(tester, key, dark ? 'ui-home-dark' : 'ui-home-light');
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('Business'), findsOneWidget);
        expect(find.text('Team'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        await tester.tap(find.text('Business'));
        await tester.pumpAndSettle();
        expect(find.text('Selected business'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('restricted member does not gain a host shortcut', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantControllerProvider.overrideWith(
            () => PreviewTenant(fixture('inventory_counter')),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome your guests'), findsNothing);
    // Inventory staff retain their existing self time-clock access.
    expect(find.text('Bring your team together'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
