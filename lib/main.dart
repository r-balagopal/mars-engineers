import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/database_helper.dart';
import 'pages/home_page.dart';
import 'pages/sites_page.dart';
import 'pages/money_page.dart';
import 'pages/settings_page.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.removeOrphanInvoices();

  runApp(const MarsEngineersApp());
}

class MarsEngineersApp extends StatelessWidget {
  const MarsEngineersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mars Engineers',
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.location_city_outlined, Icons.location_city, 'Projects'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Money'),
    (Icons.menu, Icons.menu, 'More'),
  ];

  // Only the selected page is built, so switching tabs reloads its data.
  Widget _page(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const SitesPage(),
        2 => const MoneyPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => currentIndex = i),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'MARS',
                  style: TextStyle(
                    color: kBrandRed,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _page(currentIndex)),
          ],
        ),
      );
    }

    return Scaffold(
      body: _page(currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
