import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final origin = context.read<AppState>().baseOrigin;
    _server.text = displayApiOrigin(origin);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final text = state.text;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = text.required);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.setServer(_server.text);
      await state.login(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.water_drop, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AmarSaf', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink)),
                        ],
                      ),
                    ),
                    const LanguageButton(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(text.fieldBook, style: const TextStyle(color: muted, fontSize: 16)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: text.email),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: text.password),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _server,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: text.server,
                    hintText: defaultApiOrigin,
                    helperText: text.serverHint,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: clay)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? text.signingIn : text.signIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
