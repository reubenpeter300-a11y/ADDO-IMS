import 'package:flutter/material.dart';
import 'db.dart';

class SalePage extends StatefulWidget {
  final bool swahili;
  const SalePage({super.key, required this.swahili});
  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  List<Map<String, Object?>> medicines = [];
  int? selected;
  final qty = TextEditingController(text: '1');
  final customer = TextEditingController();
  String payment = 'Cash';
  String t(String sw, String en) => widget.swahili ? sw : en;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.medicines(); if (mounted) setState(() => medicines = x); }

  @override
  Widget build(BuildContext context) {
    final m = medicines.where((x) => x['id'] == selected).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(t('Fanya mauzo','New sale'))),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<int>(
          value: selected, isExpanded: true,
          decoration: InputDecoration(labelText: t('Chagua dawa','Select medicine'), border: const OutlineInputBorder()),
          items: medicines.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['name']} (${x['quantity']} pcs)'))).toList(),
          onChanged: (v) => setState(() => selected = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Idadi ya kuuza','Quantity to sell'), border: const OutlineInputBorder())),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: payment, decoration: InputDecoration(labelText: t('Njia ya malipo','Payment method'), border: const OutlineInputBorder()),
          items: const ['Cash','Mobile Money','Card','Credit'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) => setState(() => payment = v ?? 'Cash'),
        ),
        if (payment == 'Credit') ...[
          const SizedBox(height: 12),
          TextField(controller: customer, decoration: InputDecoration(
            labelText: t('Jina la mteja wa mkopo','Credit customer name'),
            border: const OutlineInputBorder())),
        ],
        const SizedBox(height: 20),
        if (m != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(
          '${t('Jumla','Total')}: TSh ${((m['selling_price'] as num) * (int.tryParse(qty.text) ?? 0)).toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
        const Spacer(),
        FilledButton.icon(
          icon: const Icon(Icons.check), label: Text(t('Thibitisha mauzo','Complete sale')),
          onPressed: m == null ? null : () async {
            try {
              await AppDb.instance.recordSale(
                medicineId: m['id'] as int, medicineName: m['name'] as String,
                quantity: int.tryParse(qty.text) ?? 0,
                unitPrice: (m['selling_price'] as num).toDouble(),
                unitCost: (m['cost_price'] as num).toDouble(),
                paymentMethod: payment, customerName: customer.text.trim(),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Mauzo yamehifadhiwa','Sale saved'))));
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
        ),
      ])),
    );
  }
}
