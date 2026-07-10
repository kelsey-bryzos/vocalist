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

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Exact match for Home to prevent it always being highlighted
    // (since '/' is a prefix of every route)
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
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          // Always use go() — replaces the current shell route, enabling
          // back-navigation from any tab to any other tab.
          context.go(_destinations[i].route);
        },
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.inactiveIcon),
                  selectedIcon: Icon(d.activeIcon),
                  label: d.label,
                ))
            .toList(),
      ),
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
