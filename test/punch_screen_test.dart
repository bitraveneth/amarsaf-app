import 'dart:convert';

import 'package:amarsaf_field/src/api_client.dart';
import 'package:amarsaf_field/src/app_state.dart';
import 'package:amarsaf_field/src/screens/sales_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('punch screen shows in, out, and week hours from punch rows only', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    String iso(DateTime value) {
      final y = value.year.toString().padLeft(4, '0');
      final m = value.month.toString().padLeft(2, '0');
      final d = value.day.toString().padLeft(2, '0');
      final h = value.hour.toString().padLeft(2, '0');
      final min = value.minute.toString().padLeft(2, '0');
      return '$y-$m-${d}T$h:$min:00';
    }

    String? limit;
    final state = AppState(
      api: ApiClient(
        client: MockClient((request) async {
          limit = request.url.queryParameters['limit'];
          return http.Response(
            jsonEncode({
              'data': [
                {'event_type': 'punch_in', 'logged_at': iso(today)},
                {'event_type': 'ping', 'logged_at': iso(today.add(const Duration(minutes: 12)))},
                {'event_type': 'punch_out', 'logged_at': iso(today.add(const Duration(hours: 1)))},
                {'event_type': 'punch_in', 'logged_at': iso(yesterday)},
                {'event_type': 'punch_out', 'logged_at': iso(yesterday.add(const Duration(hours: 8)))},
              ],
            }),
            200,
          );
        }),
      ),
    )
      ..ready = true
      ..token = 'token'
      ..user = {'id': 3, 'name': 'Warehouse Person', 'role': 'warehouse_officer', 'employee_id': 8}
      ..punchedIn = false
      ..shiftOutAt = today.add(const Duration(hours: 1));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PunchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(limit, '1000');
    expect(find.text('Punched out 10:00'), findsOneWidget);
    expect(find.text('Punch in'), findsOneWidget);
    expect(find.text('Hours so far'), findsOneWidget);
    expect(find.text('1h 00'), findsWidgets);
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('This week'), 200);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Days with a punch'), findsOneWidget);
    expect(find.text('Late'), findsNothing);
    expect(find.text('On time'), findsNothing);
    expect(find.text('Extra'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
