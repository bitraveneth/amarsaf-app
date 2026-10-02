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
      case HomeRole.punch:
        return const PunchHomeScreen();
      case HomeRole.office:
        return const OfficeScreen();
      case HomeRole.unsupported:
        return const UnsupportedScreen();
    }
  }
}

/// Name and today's punch. No TA/DA, visits, or dealer orders.
class PunchHomeScreen extends StatelessWidget {
  const PunchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = state.text;
    return FieldScaffold(
      title: text.attendance,
      brandHeader: true,
      actions: [
        IconButton(onPressed: state.logout, icon: const Icon(Icons.logout), tooltip: text.logout),
      ],
      body: RefreshIndicator(
        onRefresh: state.refreshPunch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const QueueBanner(),
            Text(
              '${text.hello}, ${state.displayName}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.4),
            ),
            const SizedBox(height: 20),
            GroupedList(
              children: [
                GroupedRow(
                  title: text.attendance,
                  subtitle: _todayPunch(state),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchScreen()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _todayPunch(AppState state) {
    final text = state.text;
    final pending = state.queue.pendingPunch(state.userId);
    if (pending != null) return text.waitingPunch;
    if (state.shiftInAt != null && state.punchedIn) {
      return '${text.inAt} ${formatClock(state.shiftInAt!)}';
    }
    if (state.shiftInAt != null && state.shiftOutAt != null) {
      return '${text.inAt} ${formatClock(state.shiftInAt!)} · ${text.outAt} ${formatClock(state.shiftOutAt!)}';
    }
    return text.notPunched;
  }
}

class OfficeScreen extends StatelessWidget {
  const OfficeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return FieldScaffold(
      title: state.text.appName,
      brandHeader: true,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.text.officeOnly, style: const TextStyle(fontSize: 18, height: 1.4, color: ink)),
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

class UnsupportedScreen extends StatelessWidget {
  const UnsupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = '${state.user?['role'] ?? ''}'.toLowerCase();
    final message = role.contains('driver') ? state.text.driverLater : state.text.noRole;
    return FieldScaffold(
      title: state.text.appName,
      brandHeader: true,
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
