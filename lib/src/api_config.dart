const defaultApiOrigin = 'https://erp.amarsaf.com';

/// Shift pings while punched in. Kept inside the 10–15 minute window.
const shiftPingInterval = Duration(minutes: 12);

enum HomeRole { sales, dealer, punch, office, unsupported }

/// Jobs that punch in and out, and do not see the sales list.
const punchRoles = {
  'warehouse_officer',
  'production_officer',
  'qc_officer',
  'delivery_coordinator',
  'purchase_executive',
  'accounts_officer',
};

/// Origin or full `/api` root → `https://host/api` with no trailing slash.
String normalizeApiRoot(String input) {
  var value = input.trim();
  if (value.isEmpty) value = defaultApiOrigin;
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  if (value.endsWith('/api')) return value;
  return '$value/api';
}

/// What the user types in settings: the origin, without a forced `/api`.
String displayApiOrigin(String stored) {
  final root = normalizeApiRoot(stored);
  if (root.endsWith('/api')) return root.substring(0, root.length - 4);
  return root;
}

/// Home follows `user.role`. An employee id alone is not a sales login.
HomeRole resolveHomeRole(Map<String, dynamic>? user) {
  if (user == null) return HomeRole.unsupported;
  final role = '${user['role'] ?? ''}'.trim().toLowerCase();
  final hasEmployee = user['employee_id'] != null;
  final hasAgent = user['agent_id'] != null;

  if (role == 'sales_officer') return HomeRole.sales;
  if (role == 'super_admin' || role == 'admin') return HomeRole.office;
  if (punchRoles.contains(role)) {
    return hasEmployee ? HomeRole.punch : HomeRole.unsupported;
  }
  if (role.contains('driver')) return HomeRole.unsupported;
  if (hasAgent && !hasEmployee) return HomeRole.dealer;
  return HomeRole.unsupported;
}

bool homePunches(HomeRole role) => role == HomeRole.sales || role == HomeRole.punch;

String todayIso([DateTime? now]) {
  final n = now ?? DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatClock(DateTime value) {
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

double asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String taka(dynamic value) {
  return '৳${asDouble(value).toStringAsFixed(2)}';
}

DateTime? parseServerTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

class PunchDay {
  const PunchDay({this.punchedIn = false, this.inAt, this.outAt});

  final bool punchedIn;
  final DateTime? inAt;
  final DateTime? outAt;
}

/// Walk today's punch events in order. The last punch decides if the shift is open.
PunchDay interpretPunchLogs(List<dynamic> logs, {DateTime? now}) {
  final today = todayIso(now ?? DateTime.now());
  final events = <({String type, DateTime when})>[];
  for (final raw in logs) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final when = parseServerTime(item['logged_at']);
    if (when == null || todayIso(when) != today) continue;
    final type = '${item['event_type'] ?? ''}';
    if (type != 'punch_in' && type != 'punch_out') continue;
    events.add((type: type, when: when));
  }
  events.sort((a, b) => a.when.compareTo(b.when));

  DateTime? firstIn;
  DateTime? lastOut;
  var open = false;
  for (final event in events) {
    if (event.type == 'punch_in') {
      firstIn ??= event.when;
      open = true;
    } else {
      lastOut = event.when;
      open = false;
    }
  }
  return PunchDay(
    punchedIn: open,
    inAt: firstIn,
    outAt: open ? null : lastOut,
  );
}
