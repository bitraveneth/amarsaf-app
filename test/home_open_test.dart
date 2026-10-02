import 'package:amarsaf_field/main.dart';
import 'package:amarsaf_field/src/api_client.dart';
import 'package:amarsaf_field/src/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppState state() {
    return AppState(
      api: ApiClient(
        client: MockClient((request) async => http.Response('{"data":[]}', 200)),
      ),
    );
  }

  Future<AppState> pump(WidgetTester tester, AppState app) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: app, child: const AmarSafApp()),
    );
    await tester.pump();
    return app;
  }

  testWidgets('opening the app shows sign-in before a session exists', (tester) async {
    final app = state()..ready = true;
    await pump(tester, app);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each role home opens without tearing down inherited widgets', (tester) async {
    final app = state();
    await pump(tester, app);

    final cases = <Map<String, dynamic>, String>{
      {'id': 1, 'name': 'Sales Person', 'role': 'sales_officer', 'employee_id': 4}: 'Today\'s attendance',
      {'id': 2, 'name': 'Dealer Person', 'role': 'agent', 'agent_id': 9}: 'Hello, Dealer Person',
      {'id': 3, 'name': 'Warehouse Person', 'role': 'warehouse_officer', 'employee_id': 8}: 'Hello, Warehouse Person',
      {'id': 4, 'name': 'Admin Person', 'role': 'admin', 'employee_id': 1}: 'This work stays on the office computer.',
      {'id': 5, 'name': 'Driver Person', 'role': 'driver'}: 'Driver screens are not in this app yet.',
    };

    for (final entry in cases.entries) {
      app
        ..token = 'token'
        ..user = entry.key
        ..ready = true;
      app.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(entry.value), findsWidgets, reason: '${entry.key['role']}');
      expect(tester.takeException(), isNull, reason: '${entry.key['role']}');
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);

    app.token = null;
    app.user = null;
    app.notifyListeners();
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
