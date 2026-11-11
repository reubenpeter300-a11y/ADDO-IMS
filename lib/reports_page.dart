import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db.dart';

class ReportsPage extends StatefulWidget {
  final bool swahili;
  const ReportsPage({super.key, required this.swahili});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.sales(); if (mounted) setState(() => rows = x); }

  String csvCell(Object? value) {
    final v = (value ?? '').toString().replaceAll('"', '""');
    return '"$v"';
  }

  Future<void> exportCsv() async {
    final header = ['Date', 'Medicine', 'Quantity', 'Unit price', 'Total', 'Profit', 'Payment', 'Customer'];
    final lines = <String>[header.map(csvCell).join(',')];
    for (final r in rows) {
      lines.add([
        r['created_at'], r['medicine_name'], r['quantity'], r['unit_price'],
        r['total'], r['profit'], r['payment_method'], r['customer_name']
      ].map(csvCell).join(','));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ADDO_sales_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
    // UTF-8 BOM improves Kiswahili/Excel compatibility.
    await file.writeAsString('\uFEFF${lines.join('\r\n')}', flush: true);
    await Share.shareXFiles([XFile(file.path)], text: t('Ripoti ya mauzo ya ADDO Manager', 'ADDO Manager sales report'));
  }

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<num>(0, (a, b) => a + ((b['total'] as num?) ?? 0));
    final profit = rows.fold<num>(0, (a, b) => a + ((b['profit'] as num?) ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(t('Ripoti za mauzo','Sales reports'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(title: Text(t('Jumla ya mauzo (historia yote)','Total sales (all time)')),
          subtitle: Text('TSh ${money.format(total)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
        Card(child: ListTile(title: Text(t('Faida ghafi (historia yote)','Gross profit (all time)')),
          subtitle: Text('TSh ${money.format(profit)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: rows.isEmpty ? null : exportCsv,
          icon: const Icon(Icons.table_view), label: Text(t('Hamisha ripoti ya Excel (CSV)', 'Export Excel report (CSV)'))),
        const SizedBox(height: 12),
        Text(t('Historia ya miamala','Transaction history'), style: Theme.of(context).textTheme.titleLarge),
        ...rows.map((r) => Card(child: ListTile(
          title: Text('${r['medicine_name']} × ${r['quantity']}'),
          subtitle: Text('${r['payment_method']} • ${r['created_at']}'),
          trailing: Text('TSh ${money.format(r['total'] ?? 0)}'),
        ))),
        if (rows.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(t('Bado hakuna mauzo.','No sales recorded yet.')))),
      ]),
    );
  }
}
