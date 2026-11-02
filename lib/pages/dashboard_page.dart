import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int activeSites = 0;
  int closedSites = 0;
  int totalInvoices = 0;
  double outstanding = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    activeSites = await DatabaseHelper.instance.getActiveSiteCount();
    closedSites = await DatabaseHelper.instance.getClosedSiteCount();
    totalInvoices = await DatabaseHelper.instance.getInvoiceCount();
    outstanding = await DatabaseHelper.instance.getOutstandingAmount();

    if (mounted) {
      setState(() {});
    }
  }

  Widget buildCard(String title, String value, IconData icon, double screenWidth) {
    // Dynamically scale typography and icons based on screen width
    double iconSize = screenWidth * 0.09;      // ~36 on a 400px screen
    double valueFontSize = screenWidth * 0.055; // ~22 on a 400px screen
    double titleFontSize = screenWidth * 0.035; // ~14 on a 400px screen

    // Cap maximum sizes so it doesn't get absurdly huge on massive tablets/desktops
    if (iconSize > 50) iconSize = 50;
    if (valueFontSize > 28) valueFontSize = 28;
    if (titleFontSize > 16) titleFontSize = 16;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04), // Scaled internal padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Colors.blue,
            ),
            SizedBox(height: screenWidth * 0.02),
            Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Grab the screen width
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Determine dynamic spacing and layout parameters
    final double padding = screenWidth * 0.04; // 4% of screen width
    final double spacing = screenWidth * 0.035; // 3.5% spacing between items
    
    // Calculate aspect ratio dynamically to keep cards roughly square or slightly rectangular
    // Formula balances layout bounds perfectly across varying screen sizes
    final double calculatedAspectRatio = (screenWidth > 600) ? 1.3 : 1.05;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mars Engineers'),
      ),
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: GridView.count(
          crossAxisCount: screenWidth > 600 ? 3 : 2, // Automatically switches to 3 columns on wider screens/tablets
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: calculatedAspectRatio,
          children: [
            buildCard('Active Sites', activeSites.toString(), Icons.engineering, screenWidth),
            buildCard('Closed Sites', closedSites.toString(), Icons.check_circle, screenWidth),
            buildCard('Outstanding', 'Lorem${outstanding.toStringAsFixed(0)}'.replaceAll('Lorem', '₹'), Icons.currency_rupee, screenWidth),
            buildCard('Invoices', totalInvoices.toString(), Icons.receipt_long, screenWidth),
          ],
        ),
      ),
    );
  }
}