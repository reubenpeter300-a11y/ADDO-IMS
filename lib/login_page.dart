import 'package:flutter/material.dart';
import 'db.dart';
import 'home_page.dart';
import 'settings_page.dart';

class LoginPage extends StatefulWidget {
  final bool swahili;
  final ValueChanged<bool> onLanguageChanged;
  const LoginPage({super.key, required this.swahili, required this.onLanguageChanged});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(text: 'admin');
  final password = TextEditingController();
  final pin = TextEditingController();
  bool usePin = false, busy = false, obscure = true;
  String? error;
  String t(String sw, String en) => widget.swahili ? sw : en;

  Future<void> login() async {
    setState(() { busy = true; error = null; });
    final ok = usePin
        ? await AppDb.instance.verifyPin(username.text.trim(), pin.text.trim())
        : await AppDb.instance.verifyPassword(username.text.trim(), password.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) {
      setState(() => error = t('Taarifa za kuingia si sahihi.','Incorrect login details.'));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(
      swahili: widget.swahili,
      onLanguageChanged: widget.onLanguageChanged,
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleAvatar(radius: 42, backgroundColor: Color(0xFF13845B),
            child: Icon(Icons.local_pharmacy, color: Colors.white, size: 42)),
          const SizedBox(height: 16),
          const Text('ADDO MANAGER', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, letterSpacing: 1.2)),
          Text(t('Mfumo wa kusimamia duka la dawa','Pharmacy management system'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 30),
          TextField(controller: username, decoration: InputDecoration(
            labelText: t('Jina la mtumiaji','Username'), prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          if (!usePin) TextField(controller: password, obscureText: obscure, decoration: InputDecoration(
            labelText: t('Password','Password'), prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => obscure = !obscure)),
            border: const OutlineInputBorder()))
          else TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number,
            maxLength: 4, decoration: InputDecoration(labelText: t('PIN ya tarakimu 4','4-digit PIN'),
              prefixIcon: const Icon(Icons.pin), border: const OutlineInputBorder())),
          Align(alignment: Alignment.centerRight, child: TextButton(
            onPressed: () => setState(() { usePin = !usePin; error = null; }),
            child: Text(usePin ? t('Tumia password','Use password') : t('Tumia PIN','Use PIN')))),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          FilledButton(onPressed: busy ? null : login,
            child: Text(busy ? t('Inakagua...','Checking...') : t('INGIA','LOGIN'))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(swahili: widget.swahili))),
            icon: const Icon(Icons.settings), label: Text(t('Mipangilio ya akaunti','Account settings'))),
          TextButton(onPressed: () => widget.onLanguageChanged(!widget.swahili),
            child: Text(widget.swahili ? 'English' : 'Kiswahili')),
          const SizedBox(height: 12),
          const Text('OFFLINE • Data huhifadhiwa kwenye kifaa hiki',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.green)),
          const SizedBox(height: 8),
          const Text('Mara ya kwanza: admin / admin123 • PIN: 1234. Badilisha mara moja.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.red)),
        ],
      )),
    ))),
  );
}
