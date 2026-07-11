import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/router.dart';

/// Persistent shell with bottom navigation bar.
/// Wraps all main destinations: Home, Notes, Tasks, Projects.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    _Destination(kRouteHome, Icons.home_rounded, Icons.home_outlined, 'Home'),
    _Destination(
        kRouteNotes, Icons.notes_rounded, Icons.notes_outlined, 'Notes'),
    _Destination(
        kRouteTasks, Icons.checklist_rounded, Icons.checklist_outlined, 'Tasks'),
    _Destination(
        kRouteProjects, Icons.folder_rounded, Icons.folder_outlined, 'Projects'),
  ];

  // Detail routes that should hide the bottom nav
  static const _detailRoutes = [kRouteSearch];
  static const _detailPrefixes = ['/notes/', '/projects/'];

  bool _isDetailRoute(String location) {
    if (_detailRoutes.contains(location)) return true;
    for (final prefix in _detailPrefixes) {
      if (location.startsWith(prefix)) return true;
    }
    return false;
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      final route = _destinations[i].route;
      if (route == kRouteHome) {
        if (location == kRouteHome) return i;
      } else if (location.startsWith(route)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNav = !_isDetailRoute(location);
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) {
                context.go(_destinations[i].route);
              },
              destinations: _destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.inactiveIcon),
                        selectedIcon: Icon(d.activeIcon),
                        label: d.label,
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _Destination {
  const _Destination(
      this.route, this.activeIcon, this.inactiveIcon, this.label);

  final String route;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
}
