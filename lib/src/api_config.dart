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

class PunchSpan {
  const PunchSpan({this.inAt, this.outAt, this.hours = Duration.zero});

  final DateTime? inAt;
  final DateTime? outAt;
  final Duration hours;
}

class PunchSummary {
  const PunchSummary({
    required this.today,
    required this.yesterday,
    required this.weekDays,
    required this.weekHours,
  });

  final PunchSpan today;
  final PunchSpan yesterday;
  final int weekDays;
  final Duration weekHours;
}

/// Hours come only from punch_in / punch_out pairs. Ping rows are ignored.
/// An open punch counts up to [now] on today only. A missing out is left empty.
PunchSummary summarizePunchLogs(List<dynamic> logs, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = todayIso(clock);
  final yesterday = todayIso(clock.subtract(const Duration(days: 1)));
  final weekStart = _mondayOf(clock);

  final events = <({String type, DateTime when})>[];
  for (final raw in logs) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final when = parseServerTime(item['logged_at']);
    if (when == null) continue;
    final type = '${item['event_type'] ?? ''}';
    if (type != 'punch_in' && type != 'punch_out') continue;
    if (todayIso(when).compareTo(today) > 0) continue;
    events.add((type: type, when: when));
  }
  events.sort((a, b) => a.when.compareTo(b.when));

  final days = <String, _DayPunches>{};
  for (final event in events) {
    final key = todayIso(event.when);
    final day = days.putIfAbsent(key, _DayPunches.new);
    if (event.type == 'punch_in') {
      day.firstIn ??= event.when;
      day.openIn ??= event.when;
    } else {
      day.lastOut = event.when;
      final opened = day.openIn;
      if (opened != null) {
        final gap = event.when.difference(opened);
        if (!gap.isNegative) day.closed += gap;
        day.openIn = null;
      }
    }
  }

  Duration hoursFor(String key, {required bool countOpen}) {
    final day = days[key];
    if (day == null) return Duration.zero;
    var total = day.closed;
    if (countOpen && day.openIn != null) {
      final gap = clock.difference(day.openIn!);
      if (!gap.isNegative) total += gap;
    }
    return total;
  }

  PunchSpan spanFor(String key, {required bool countOpen}) {
    final day = days[key];
    return PunchSpan(
      inAt: day?.firstIn,
      outAt: day?.lastOut,
      hours: hoursFor(key, countOpen: countOpen),
    );
  }

  var weekDays = 0;
  var weekHours = Duration.zero;
  for (final entry in days.entries) {
    if (_localDay(entry.key).isBefore(weekStart)) continue;
    weekDays += 1;
    weekHours += hoursFor(entry.key, countOpen: entry.key == today);
  }

  return PunchSummary(
    today: spanFor(today, countOpen: true),
    yesterday: spanFor(yesterday, countOpen: false),
    weekDays: weekDays,
    weekHours: weekHours,
  );
}

DateTime _mondayOf(DateTime clock) {
  final day = DateTime(clock.year, clock.month, clock.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime _localDay(String isoDay) {
  final parts = isoDay.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

class _DayPunches {
  DateTime? firstIn;
  DateTime? lastOut;
  DateTime? openIn;
  Duration closed = Duration.zero;
}
