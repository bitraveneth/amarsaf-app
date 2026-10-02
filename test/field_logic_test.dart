import 'package:amarsaf_field/src/api_config.dart';
import 'package:amarsaf_field/src/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api root defaults to the live ERP and does not double the /api suffix', () {
    expect(normalizeApiRoot(''), 'https://erp.amarsaf.com/api');
    expect(normalizeApiRoot('https://erp.amarsaf.com'), 'https://erp.amarsaf.com/api');
    expect(normalizeApiRoot('https://erp.amarsaf.com/'), 'https://erp.amarsaf.com/api');
    expect(normalizeApiRoot('https://erp.amarsaf.com/api'), 'https://erp.amarsaf.com/api');
    expect(normalizeApiRoot('erp.local.test'), 'https://erp.local.test/api');
    expect(displayApiOrigin('https://erp.amarsaf.com/api'), 'https://erp.amarsaf.com');
  });

  test('login payload picks sales, dealer, or neither', () {
    expect(resolveHomeRole({'employee_id': 4, 'agent_id': null, 'role': 'sales_officer'}), HomeRole.sales);
    expect(resolveHomeRole({'employee_id': null, 'agent_id': 9, 'role': 'agent'}), HomeRole.dealer);
    expect(resolveHomeRole({'employee_id': 4, 'agent_id': 9, 'role': 'sales_officer'}), HomeRole.sales);
    expect(resolveHomeRole({'employee_id': null, 'agent_id': null, 'role': 'driver'}), HomeRole.unsupported);
  });

  test('shift pings sit between 10 and 15 minutes', () {
    expect(shiftPingInterval.inMinutes, inInclusiveRange(10, 15));
  });

  test('punch state follows the last punch of the day', () {
    final open = interpretPunchLogs([
      {'event_type': 'punch_in', 'logged_at': '2026-10-02T09:05:00'},
      {'event_type': 'ping', 'logged_at': '2026-10-02T09:20:00'},
    ], now: DateTime(2026, 10, 2, 11));
    expect(open.punchedIn, isTrue);
    expect(open.inAt?.hour, 9);

    final closed = interpretPunchLogs([
      {'event_type': 'punch_in', 'logged_at': '2026-10-02T09:05:00'},
      {'event_type': 'punch_out', 'logged_at': '2026-10-02T17:40:00'},
    ], now: DateTime(2026, 10, 2, 18));
    expect(closed.punchedIn, isFalse);
    expect(closed.outAt?.hour, 17);

    final yesterday = interpretPunchLogs([
      {'event_type': 'punch_in', 'logged_at': '2026-10-01T09:05:00'},
    ], now: DateTime(2026, 10, 2, 8));
    expect(yesterday.punchedIn, isFalse);
  });

  test('visit complete waits for the queued visit create', () {
    final queue = OfflineQueue();
    queue.add(QueuedJob(id: 'create', userId: '7', type: 'visit_create', body: {'agent_id': 3}));
    queue.add(QueuedJob(
      id: 'done',
      userId: '7',
      type: 'visit_complete',
      body: {'plan_id': null},
      dependsOn: 'create',
    ));
    queue.add(QueuedJob(id: 'punch', userId: '7', type: 'punch_in', body: const {}));

    expect(queue.ready().map((job) => job.id), ['create', 'punch']);
    expect(queue.pendingPunch('7'), 'in');

    queue.remove('create');
    queue.jobs.firstWhere((job) => job.id == 'done').body['plan_id'] = 15;
    expect(queue.ready().map((job) => job.id), ['done', 'punch']);

    final restored = OfflineQueue.decode(queue.encode());
    expect(restored.jobs.singleWhere((job) => job.id == 'done').body['plan_id'], 15);

    queue.markFailed('done', 'Dealer was already visited.');
    expect(queue.ready().map((job) => job.id), ['punch']);
    expect(queue.failedFor('7'), 1);
  });
}