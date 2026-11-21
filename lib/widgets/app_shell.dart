import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'glass_card.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.items, required this.rol});
  final List<NavItem> items;
  final String rol;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  Future<void> _salir() => Supabase.instance.client.auth.signOut();

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: items[_index].page,
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 600;
      final extended = c.maxWidth >= 1024;

      if (!wide) {
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Image.asset('assets/logo.png', height: 34),
              const SizedBox(width: 10),
              Text(widget.rol,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            actions: [
              IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: _salir),
            ],
          ),
          body: body,
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: NavigationBar(
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final it in items)
                    NavigationDestination(icon: Icon(it.icon), label: it.label),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GlassCard(
                padding: EdgeInsets.zero,
                radius: 28,
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  extended: extended,
                  selectedIndex: _index,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Column(children: [
                      Image.asset('assets/logo.png', height: extended ? 90 : 52),
                      const SizedBox(height: 4),
                      Text(widget.rol,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  destinations: [
                    for (final it in items)
                      NavigationRailDestination(
                          icon: Icon(it.icon), label: Text(it.label)),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                            tooltip: 'Cerrar sesión',
                            icon: const Icon(Icons.logout),
                            onPressed: _salir),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    });
  }
}