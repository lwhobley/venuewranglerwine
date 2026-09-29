import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/dashboard/presentation/workspace_pages.dart';
import '../features/data_import/presentation/data_import_page.dart';
import '../features/floor_plan/presentation/floor_host_page.dart';
import '../features/onboarding/application/tenant_controller.dart';
import '../features/onboarding/presentation/auth_pages.dart';
import '../features/onboarding/presentation/onboarding_pages.dart';
import '../features/operations/presentation/business_page.dart';
import '../features/operations/presentation/host_page.dart';
import '../features/operations/presentation/people_page.dart';
import '../features/workforce/presentation/workforce_page.dart';
import '../features/wine_inventory/presentation/cellar_pages.dart';
import '../features/wine_inventory/presentation/count_pages.dart';
import '../features/wine_inventory/presentation/allocation_pages.dart';
import '../features/wine_inventory/presentation/movement_pages.dart';
import '../features/wine_inventory/presentation/service_pages.dart';
import 'redirect.dart';

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    _auth = ref.listen(authControllerProvider, (_, _) => notifyListeners());
    _tenant = ref.listen(tenantControllerProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<Object?> _auth;
  late final ProviderSubscription<Object?> _tenant;

  @override
  void dispose() {
    _auth.close();
    _tenant.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      return resolveRedirect(
        auth: ref.read(authControllerProvider),
        tenant: ref.read(tenantControllerProvider),
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/setup', builder: (context, state) => const SetupPage()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInPage()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpPage()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordPage()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailPage()),
      GoRoute(path: '/auth/recovery', builder: (context, state) => const RecoveryPage()),
      GoRoute(
        path: '/onboarding/organization',
        builder: (context, state) => const CreateOrganizationPage(),
      ),
      GoRoute(path: '/onboarding/venue', builder: (context, state) => const CreateVenuePage()),
      GoRoute(path: '/onboarding/join', builder: (context, state) => const JoinVenuePage()),
      GoRoute(
        path: '/invite',
        builder: (context, state) => AcceptInvitePage(initialToken: state.uri.queryParameters['token']),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/app/home', builder: (context, state) => const HomePage()),
          GoRoute(path: '/app/import', builder: (context, state) => const DataImportPage()),
          GoRoute(path: '/app/cellar', builder: (context, state) => const CellarPage()),
          GoRoute(path: '/app/cellar/import', builder: (context, state) => const WineImportPage()),
          GoRoute(path: '/app/cellar/receive', builder: (context, state) => const ReceivePage()),
          GoRoute(path: '/app/cellar/move', builder: (context, state) => const MovementPage()),
          GoRoute(path: '/app/cellar/allocations', builder: (context, state) => const AllocationPage()),
          GoRoute(path: '/app/cellar/service', builder: (context, state) => const ServicePage()),
          GoRoute(path: '/app/cellar/counts', builder: (context, state) => const CountSessionsPage()),
          GoRoute(
            path: '/app/cellar/counts/:id/review',
            builder: (context, state) => CountReviewPage(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cellar/counts/:id',
            builder: (context, state) => CountModePage(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/app/host', builder: (context, state) => const HostPage(),
            onExit: (context, state) => ref.read(floorExitGuardProvider).canLeave()),
          GoRoute(path: '/app/people', builder: (context, state) => const PeoplePage()),
          GoRoute(path: '/app/scheduling', builder: (context, state) => WorkforcePage(initialShift: state.uri.queryParameters['shift'])),
          GoRoute(path: '/app/business', builder: (context, state) => const BusinessPage()),
          GoRoute(path: '/app/team', builder: (context, state) => const TeamPage()),
          GoRoute(path: '/app/profile', builder: (context, state) => const ProfilePage()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
