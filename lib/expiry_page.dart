import 'package:flutter/material.dart';
import 'db.dart';

class ExpiryPage extends StatefulWidget {
  final bool swahili;
  const ExpiryPage({super.key, required this.swahili});
  @override
  State<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.expiringMedicines(); if (mounted) setState(() => rows = x); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Tahadhari za expiry','Expiry alerts'))),
    body: rows.isEmpty ? Center(child: Text(t('Hakuna dawa zenye expiry ndani ya siku 90.','No medicines expiring within the next 90 days.'))) :
      ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
        final x = rows[i];
        return Card(child: ListTile(
          leading: const Icon(Icons.event_busy, color: Colors.orange),
          title: Text('${x['name']}'),
          subtitle: Text('Batch: ${x['batch_no']} • Exp: ${x['expiry_date']}'),
          trailing: Text('${x['quantity']} pcs'),
        ));
      }),
  );
}
