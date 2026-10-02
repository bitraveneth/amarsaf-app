import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'l10n.dart';
import 'offline_queue.dart';

class SubmitResult {
  const SubmitResult({required this.queued, this.response});

  final bool queued;
  final Map<String, dynamic>? response;
}

class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  SharedPreferences? _prefs;

  bool ready = false;
  String baseOrigin = defaultApiOrigin;
  String language = 'en';
  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic>? employee;
  Map<String, dynamic>? agent;
  OfflineQueue queue = OfflineQueue();

  bool punchedIn = false;
  DateTime? shiftInAt;
  DateTime? shiftOutAt;
  DateTime? lastPingAt;
  String? banner;

  Timer? _pingTimer;
  bool _pinging = false;
  bool flushing = false;

  L10n get text => L10n(language);
  HomeRole get role => resolveHomeRole(user);
  String get apiRoot => normalizeApiRoot(baseOrigin);
  String get userId => '${user?['id'] ?? ''}';
  String get displayName => '${user?['name'] ?? employee?['name'] ?? agent?['name'] ?? ''}';

  bool get shouldPing =>
      token != null && homePunches(role) && punchedIn && queue.pendingPunch(userId) == null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    baseOrigin = prefs.getString('api_origin') ?? defaultApiOrigin;
    language = prefs.getString('language') ?? 'en';
    token = prefs.getString('token');
    user = _readMap('user');
    employee = _readMap('employee');
    agent = _readMap('agent');
    queue = OfflineQueue.decode(prefs.getString('queue'));
    ready = true;
    notifyListeners();
    if (token != null) {
      await refreshPunch();
      await flushQueue();
      if (shouldPing) await sendPing(force: true);
    }
  }

  Future<void> setLanguage(String code) async {
    language = code == 'bn' ? 'bn' : 'en';
    await _prefs?.setString('language', language);
    notifyListeners();
  }

  Future<void> setServer(String value) async {
    baseOrigin = value.trim().isEmpty ? defaultApiOrigin : value.trim();
    await _prefs?.setString('api_origin', baseOrigin);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await _api.postJson(
      apiRoot,
      '/login',
      body: {'email': email.trim(), 'password': password},
    );
    final nextToken = response['token'];
    if (nextToken is! String || nextToken.isEmpty) {
      throw ApiException('The server did not return a token.');
    }
    token = nextToken;
    user = _asMap(response['user']);
    employee = _asMap(response['employee']);
    agent = _asMap(response['agent']);
    await _persistSession();
    notifyListeners();
    await refreshPunch();
    await flushQueue();
    if (shouldPing) await sendPing(force: true);
  }

  Future<void> logout() async {
    final current = token;
    token = null;
    user = null;
    employee = null;
    agent = null;
    punchedIn = false;
    shiftInAt = null;
    shiftOutAt = null;
    _pingTimer?.cancel();
    await _persistSession();
    notifyListeners();
    if (current != null) {
      try {
        await _api.postJson(apiRoot, '/logout', token: current);
      } catch (_) {
        // Local sign-out still stands if the server is unreachable.
      }
    }
  }

  Future<Map<String, dynamic>> fetch(String path, {Map<String, String>? query}) async {
    try {
      return await _api.getJson(apiRoot, path, token: token, query: query);
    } on ApiException catch (error) {
      if (error.status == 401) await logout();
      rethrow;
    }
  }

  Future<SubmitResult> punch(bool clockIn) async {
    final position = await _position();
    final result = await _sendOrQueue(
      type: clockIn ? 'punch_in' : 'punch_out',
      body: {
        'logged_at': DateTime.now().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
    );
    if (clockIn && !result.queued) lastPingAt = DateTime.now();
    await refreshPunch();
    _armPinger();
    return result;
  }

  Future<void> refreshPunch() async {
    if (token == null || !homePunches(role)) {
      // Notifying here used to run while the home screen was still mounting
      // and registering inherited-widget listeners.
      if (punchedIn || shiftInAt != null || shiftOutAt != null) {
        punchedIn = false;
        shiftInAt = null;
        shiftOutAt = null;
        notifyListeners();
      }
      return;
    }
    try {
      final response = await _api.getJson(
        apiRoot,
        '/employee/location-logs',
        token: token,
        query: const {'limit': '40'},
      );
      final data = response['data'];
      final day = interpretPunchLogs(data is List ? data : const []);
      punchedIn = day.punchedIn;
      shiftInAt = day.inAt;
      shiftOutAt = day.outAt;
    } catch (error) {
      if (error is ApiException && error.status == 401) await logout();
    }
    notifyListeners();
    _armPinger();
  }

  Future<void> onResume() async {
    if (token == null) return;
    await refreshPunch();
    await flushQueue();
    if (shouldPing) {
      final due = lastPingAt == null || DateTime.now().difference(lastPingAt!) >= shiftPingInterval;
      if (due) await sendPing(force: true);
    }
  }

  Future<void> sendPing({bool force = false}) async {
    if (!shouldPing || _pinging) return;
    if (!force && lastPingAt != null && DateTime.now().difference(lastPingAt!) < shiftPingInterval) {
      return;
    }
    _pinging = true;
    try {
      final position = await _position();
      await _api.postJson(
        apiRoot,
        '/employee/location-logs',
        token: token,
        body: {
          'logged_at': DateTime.now().toIso8601String(),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'source': 'mobile',
          'event_type': 'ping',
        },
      );
      lastPingAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Shift pings are best-effort. Punch, visits, bills, and orders are queued.
    } finally {
      _pinging = false;
    }
  }

  Future<SubmitResult> addVisit({
    required int agentId,
    required String date,
    String? title,
    String? notes,
  }) {
    return _sendOrQueue(
      type: 'visit_create',
      body: {
        'agent_id': agentId,
        'date': date,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<SubmitResult> completeVisit({
    required int planId,
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) {
    return _sendOrQueue(
      type: 'visit_complete',
      body: {
        'plan_id': planId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationLabel != null && locationLabel.isNotEmpty) 'location_label': locationLabel,
      },
    );
  }

  Future<SubmitResult> submitAllowance({
    required String type,
    required String date,
    required double amount,
    String? description,
    String? photoPath,
  }) {
    return _sendOrQueue(
      type: 'allowance',
      filePath: photoPath,
      body: {
        'type': type,
        'date': date,
        'amount': amount.toStringAsFixed(2),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
  }

  Future<SubmitResult> placeOrder({
    required bool forEmployee,
    int? agentId,
    required String orderType,
    String? notes,
    String? deliveryDate,
    required List<Map<String, dynamic>> items,
  }) {
    final date = deliveryDate?.trim();
    return _sendOrQueue(
      type: forEmployee ? 'order_employee' : 'order_agent',
      body: {
        if (forEmployee) 'agent_id': agentId,
        'order_type': orderType,
        if (date != null && date.isNotEmpty) 'delivery_date': date,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'items': items,
      },
    );
  }

  Future<int> flushQueue() async {
    if (flushing || token == null || userId.isEmpty) return 0;
    flushing = true;
    notifyListeners();
    var sent = 0;
    try {
      while (true) {
        final pending = queue.ready().where((job) => job.userId == userId).toList();
        if (pending.isEmpty) break;
        final job = pending.first;
        try {
          final response = await _dispatch(job);
          if (job.type == 'visit_create') {
            final serverId = response['id'];
            for (final other in queue.jobs) {
              if (other.dependsOn == job.id && serverId != null) {
                other.body['plan_id'] = serverId;
              }
            }
          }
          queue.remove(job.id);
          await _deleteQueuedFile(job.filePath);
          sent++;
          await _persistQueue();
        } on ApiException catch (error) {
          if (error.offline) break;
          if (error.status == 401) {
            await logout();
            break;
          }
          queue.markFailed(job.id, error.message);
          await _persistQueue();
        }
      }
    } finally {
      flushing = false;
      notifyListeners();
    }
    if (token != null) await refreshPunch();
    return sent;
  }

  Future<void> discardFailed() async {
    queue.discardFailed(userId);
    await _persistQueue();
    notifyListeners();
  }

  void showBanner(String message) {
    banner = message;
    notifyListeners();
  }

  void clearBanner() {
    banner = null;
    notifyListeners();
  }

  Future<SubmitResult> _sendOrQueue({
    required String type,
    required Map<String, dynamic> body,
    String? filePath,
    String? dependsOn,
  }) async {
    try {
      final response = await _dispatch(
        QueuedJob(id: 'live', userId: userId, type: type, body: body, filePath: filePath),
      );
      return SubmitResult(queued: false, response: response);
    } on ApiException catch (error) {
      if (!error.offline) rethrow;
      final id = queue.nextId();
      final stored = filePath == null ? null : await _keepFile(filePath, id);
      queue.add(
        QueuedJob(
          id: id,
          userId: userId,
          type: type,
          body: Map<String, dynamic>.from(body),
          filePath: stored,
          dependsOn: dependsOn,
        ),
      );
      await _persistQueue();
      notifyListeners();
      return const SubmitResult(queued: true);
    }
  }

  Future<Map<String, dynamic>> _dispatch(QueuedJob job) {
    switch (job.type) {
      case 'punch_in':
        return _api.postJson(apiRoot, '/employee/attendance/punch-in', token: token, body: job.body);
      case 'punch_out':
        return _api.postJson(apiRoot, '/employee/attendance/punch-out', token: token, body: job.body);
      case 'visit_create':
        return _api.postJson(apiRoot, '/employee/visit-plans', token: token, body: job.body);
      case 'visit_complete':
        final planId = job.body['plan_id'];
        final payload = Map<String, dynamic>.from(job.body)..remove('plan_id');
        return _api.postJson(
          apiRoot,
          '/employee/visit-plans/$planId/complete',
          token: token,
          body: payload,
        );
      case 'allowance':
        final fields = <String, String>{};
        job.body.forEach((key, value) {
          if (value != null) fields[key] = '$value';
        });
        return _api.postMultipart(
          apiRoot,
          '/employee/allowances',
          token: token ?? '',
          fields: fields,
          filePath: job.filePath,
        );
      case 'order_employee':
        return _api.postJson(apiRoot, '/employee/orders', token: token, body: job.body);
      case 'order_agent':
        return _api.postJson(apiRoot, '/agent/orders', token: token, body: job.body);
      default:
        throw ApiException('Unknown queued action.');
    }
  }

  Future<Position> capturePosition() => _position();

  Future<Position> _position() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw ApiException(text.locationNeeded);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw ApiException(text.locationNeeded);
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  void _armPinger() {
    _pingTimer?.cancel();
    if (!shouldPing) return;
    _pingTimer = Timer.periodic(shiftPingInterval, (_) => sendPing());
  }

  Future<String> _keepFile(String source, String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/queue_files');
    if (!await folder.exists()) await folder.create(recursive: true);
    final dot = source.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : source.substring(dot + 1);
    final dest = File('${folder.path}/$id.$ext');
    await File(source).copy(dest.path);
    return dest.path;
  }

  Future<void> _deleteQueuedFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Map<String, dynamic>? _readMap(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final parsed = jsonDecode(raw);
    return _asMap(parsed);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<void> _persistSession() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (token == null) {
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('employee');
      await prefs.remove('agent');
    } else {
      await prefs.setString('token', token!);
      await prefs.setString('user', jsonEncode(user));
      await prefs.setString('employee', jsonEncode(employee));
      await prefs.setString('agent', jsonEncode(agent));
    }
    await prefs.setString('api_origin', baseOrigin);
    await prefs.setString('language', language);
  }

  Future<void> _persistQueue() async {
    await _prefs?.setString('queue', queue.encode());
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }
}
