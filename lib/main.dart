import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'pages/dashboard_page.dart';
import 'pages/sites_page.dart';
import 'pages/invoices_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


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
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  final pages = const [
  DashboardPage(),
  SitesPage(),
  InvoicesPage(),
  SettingsPage(),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
  type: BottomNavigationBarType.fixed,
  currentIndex: currentIndex,
  onTap: (index) {
    setState(() {
      currentIndex = index;
    });
  },
        items: const [
  BottomNavigationBarItem(
    icon: Icon(Icons.dashboard),
    label: 'Dashboard',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.location_city),
    label: 'Sites',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.receipt_long),
    label: 'Invoices',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.settings),
    label: 'Settings',
  ),
],
      ),
    );
  }
}