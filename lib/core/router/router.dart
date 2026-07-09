import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/home/screens/home_screen.dart';

// Route name constants
const kRouteSignIn = '/sign-in';
const kRouteSignUp = '/sign-up';
const kRouteHome = '/';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: kRouteHome,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isAuthenticated = authState.valueOrNull?.session != null;
      final isOnAuthRoute = state.matchedLocation == kRouteSignIn ||
          state.matchedLocation == kRouteSignUp;

      if (!isAuthenticated && !isOnAuthRoute) return kRouteSignIn;
      if (isAuthenticated && isOnAuthRoute) return kRouteHome;
      return null;
    },
    routes: [
      GoRoute(
        path: kRouteHome,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: kRouteSignIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: kRouteSignUp,
        builder: (context, state) => const SignUpScreen(),
      ),
    ],
  );
});
