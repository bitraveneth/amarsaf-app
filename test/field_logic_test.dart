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

  test('home follows the job, not merely an employee id', () {
    expect(resolveHomeRole({'employee_id': 4, 'agent_id': null, 'role': 'sales_officer'}), HomeRole.sales);
    expect(resolveHomeRole({'employee_id': null, 'agent_id': 9, 'role': 'agent'}), HomeRole.dealer);
    expect(resolveHomeRole({'employee_id': 4, 'agent_id': 9, 'role': 'sales_officer'}), HomeRole.sales);
    expect(resolveHomeRole({'employee_id': null, 'agent_id': null, 'role': 'driver'}), HomeRole.unsupported);
    expect(resolveHomeRole({'employee_id': 4, 'role': 'driver'}), HomeRole.unsupported);

    for (final role in punchRoles) {
      expect(resolveHomeRole({'employee_id': 8, 'role': role}), HomeRole.punch, reason: role);
      expect(resolveHomeRole({'employee_id': null, 'agent_id': 3, 'role': role}), HomeRole.unsupported, reason: role);
    }

    expect(resolveHomeRole({'employee_id': 1, 'role': 'admin'}), HomeRole.office);
    expect(resolveHomeRole({'employee_id': 1, 'role': 'super_admin'}), HomeRole.office);
    expect(resolveHomeRole({'employee_id': 4, 'agent_id': null}), HomeRole.unsupported);
    expect(resolveHomeRole(null), HomeRole.unsupported);
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

  test('punch summary uses in/out pairs and skips pings', () {
    final now = DateTime(2026, 10, 2, 11);
    expect(now.weekday, DateTime.friday);

    final summary = summarizePunchLogs([
      {'event_type': 'punch_in', 'logged_at': '2026-09-27T09:00:00'},
      {'event_type': 'punch_out', 'logged_at': '2026-09-27T17:00:00'},
      {'event_type': 'punch_in', 'logged_at': '2026-09-28T09:00:00'},
      {'event_type': 'punch_out', 'logged_at': '2026-09-28T12:00:00'},
      {'event_type': 'punch_in', 'logged_at': '2026-10-01T08:30:00'},
      {'event_type': 'ping', 'logged_at': '2026-10-01T09:00:00'},
      {'event_type': 'punch_out', 'logged_at': '2026-10-01T16:30:00'},
      {'event_type': 'punch_in', 'logged_at': '2026-10-02T09:05:00'},
      {'event_type': 'ping', 'logged_at': '2026-10-02T09:20:00'},
      {'event_type': 'punch_out', 'logged_at': '2026-10-02T10:05:00'},
      {'event_type': 'punch_in', 'logged_at': '2026-10-02T10:15:00'},
    ], now: now);

    expect(summary.today.inAt?.hour, 9);
    expect(summary.today.outAt?.hour, 10);
    expect(summary.today.hours, const Duration(hours: 1, minutes: 45));
    expect(summary.yesterday.inAt?.hour, 8);
    expect(summary.yesterday.outAt?.hour, 16);
    expect(summary.weekDays, 3);
    expect(summary.weekHours, const Duration(hours: 12, minutes: 45));
  });

  test('an open punch from yesterday does not invent an out or hours', () {
    final summary = summarizePunchLogs([
      {'event_type': 'punch_in', 'logged_at': '2026-10-01T09:00:00'},
    ], now: DateTime(2026, 10, 2, 11));

    expect(summary.yesterday.inAt?.hour, 9);
    expect(summary.yesterday.outAt, isNull);
    expect(summary.yesterday.hours, Duration.zero);
    expect(summary.today.inAt, isNull);
    expect(summary.weekHours, Duration.zero);
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