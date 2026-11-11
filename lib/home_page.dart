import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db.dart';
import 'medicines_page.dart';
import 'sale_page.dart';
import 'reports_page.dart';
import 'purchases_page.dart';
import 'suppliers_page.dart';
import 'expenses_page.dart';
import 'expiry_page.dart';
import 'debts_page.dart';
import 'supplier_debts_page.dart';

class HomePage extends StatefulWidget {
  final bool swahili;
  final ValueChanged<bool> onLanguageChanged;
  const HomePage({super.key, required this.swahili, required this.onLanguageChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, num> stats = {};
  bool loading = true;
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    final result = await AppDb.instance.summary();
    if (!mounted) return;
    setState(() { stats = result; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADDO Manager'),
        actions: [
          TextButton(
            onPressed: () => widget.onLanguageChanged(!widget.swahili),
            child: Text(widget.swahili ? 'EN' : 'SW', style: const TextStyle(color: Colors.white)),
          ),
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t('Muhtasari wa biashara','Business overview'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
              children: [
                _stat(t('Mauzo ya leo','Today sales'), 'TSh ${money.format(stats['sales'] ?? 0)}', Icons.point_of_sale, Colors.green),
                _stat(t('Faida ghafi leo','Gross profit today'), 'TSh ${money.format(stats['profit'] ?? 0)}', Icons.trending_up, Colors.blue),
                _stat(t('Jumla ya stock','Total stock units'), '${stats['stock'] ?? 0}', Icons.medication, Colors.deepPurple),
                _stat(t('Stock ndogo','Low stock items'), '${stats['low'] ?? 0}', Icons.warning_amber, Colors.orange),
              ],
            ),
            const SizedBox(height: 22),
            Text(t('Vitendo vya haraka','Quick actions'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _action(context, t('Dawa / Stock','Medicines / Stock'), Icons.medication, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicinesPage(swahili: widget.swahili)));
              refresh();
            }),
            _action(context, t('Fanya mauzo','Make a sale'), Icons.shopping_cart, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => SalePage(swahili: widget.swahili)));
              refresh();
            }),
            _action(context, t('Ripoti za mauzo','Sales reports'), Icons.analytics, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(swahili: widget.swahili)));
            }),
            _action(context, t('Manunuzi / Pokea mzigo','Purchases / Receive stock'), Icons.inventory, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasesPage(swahili: widget.swahili)));
              refresh();
            }),
            _action(context, t('Wasambazaji','Suppliers'), Icons.local_shipping, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SuppliersPage(swahili: widget.swahili)));
            }),
            _action(context, t('Matumizi ya duka','Shop expenses'), Icons.account_balance_wallet, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(swahili: widget.swahili)));
            }),
            _action(context, t('Dawa zinazokaribia expiry','Expiry alerts'), Icons.event_busy, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExpiryPage(swahili: widget.swahili)));
            }),
            _action(context, t('Madeni ya wateja','Customer debts'), Icons.people, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DebtsPage(swahili: widget.swahili)));
            }),
            _action(context, t('Madeni ya suppliers','Supplier balances'), Icons.request_quote, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDebtsPage(swahili: widget.swahili)));
            }),
            const SizedBox(height: 12),
            const Card(child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.offline_bolt, color: Colors.green),
                SizedBox(width: 10),
                Expanded(child: Text('OFFLINE MODE: Taarifa zinahifadhiwa kwenye simu hii.')),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon, Color color) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Icon(icon, color: color), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54))],
    )),
  );

  Widget _action(BuildContext context, String title, IconData icon, VoidCallback onTap) => Card(
    child: ListTile(leading: Icon(icon, color: Colors.green), title: Text(title),
      trailing: const Icon(Icons.chevron_right), onTap: onTap),
  );
}
