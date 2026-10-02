import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'src/api_config.dart';
import 'src/app_state.dart';
import 'src/screens/dealer_screens.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/sales_screens.dart';
import 'src/theme.dart';
import 'src/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const AmarSafApp(),
    ),
  );
  state.bootstrap();
}

class AmarSafApp extends StatefulWidget {
  const AmarSafApp({super.key});

  @override
  State<AmarSafApp> createState() => _AmarSafAppState();
}

class _AmarSafAppState extends State<AmarSafApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'AmarSaf Field',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(app.language == 'bn' ? 'bn' : 'en'),
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _home(app),
    );
  }

  Widget _home(AppState app) {
    if (!app.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (app.token == null) return const LoginScreen();
    switch (app.role) {
      case HomeRole.sales:
        return const SalesHomeScreen();
      case HomeRole.dealer:
        return const DealerHomeScreen();
      case HomeRole.unsupported:
        return const UnsupportedScreen();
    }
  }
}

class UnsupportedScreen extends StatelessWidget {
  const UnsupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = '${state.user?['role'] ?? ''}'.toLowerCase();
    final message = role.contains('driver') ? state.text.driverLater : state.text.noRole;
    return FieldScaffold(
      title: state.text.appName,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 18, height: 1.4, color: ink)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.logout,
              child: Text(state.text.logout),
            ),
          ],
        ),
      ),
    );
  }
}
