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
  bool _hidePassword = true;
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

  Future<void> _editServer() async {
    final text = context.read<AppState>().text;
    final draft = TextEditingController(text: _server.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.server),
        content: TextField(
          controller: draft,
          autocorrect: false,
          autofocus: true,
          decoration: InputDecoration(
            hintText: defaultApiOrigin,
            helperText: text.serverHint,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(text.save)),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() => _server.text = draft.text.trim());
      await context.read<AppState>().setServer(_server.text);
    }
    draft.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageButton(),
                ),
                const SizedBox(height: 36),
                const Center(child: BrandWordmark(height: 56)),
                const SizedBox(height: 12),
                Text(
                  text.fieldBook,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 17),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: text.email),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: text.password,
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? text.showPassword : text.hidePassword,
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
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
                const SizedBox(height: 22),
                Text(
                  text.accountFromOffice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(text.forgotPassword),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _editServer,
                    child: Text(text.server),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mobile API has no password-reset route, so this screen only tells
/// the person to ask the office. It never claims a reset email was sent.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    return FieldScaffold(
      title: text.forgotPassword,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            text.officeResetsPassword,
            style: const TextStyle(fontSize: 17, height: 1.45, color: ink),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(text.back),
            ),
          ),
        ],
      ),
    );
  }
}
