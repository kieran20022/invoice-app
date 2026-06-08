import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../config/theme.dart';
import '../invoices/invoice_history_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../products/products_screen.dart';
import '../business/business_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InvoiceHistoryScreen(),
    ProductsScreen(),
    BusinessInfoScreen(isFirstTime: false),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = context.watch<BusinessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              business.businessInfo?.name.isNotEmpty == true
                  ? business.businessInfo!.name
                  : 'Facturatie App',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (auth.user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _showProfileMenu,
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(auth.user!.photoURL!),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: _showProfileMenu,
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'home_new_invoice',
              onPressed: _openCreateInvoice,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nieuwe Factuur',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Facturen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Producten',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              label: 'Instellingen',
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateInvoice() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()));
  }

  void _showProfileMenu() {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (auth.user?.photoURL != null)
                CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(auth.user!.photoURL!),
                ),
              const SizedBox(height: 12),
              Text(
                auth.user?.displayName ?? 'Gebruiker',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                auth.user?.email ?? '',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: const Text(
                  'Uitloggen',
                  style: TextStyle(color: AppTheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
