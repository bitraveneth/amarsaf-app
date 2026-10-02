import 'dart:convert';

class QueuedJob {
  QueuedJob({
    required this.id,
    required this.userId,
    required this.type,
    required Map<String, dynamic> body,
    this.filePath,
    this.dependsOn,
    this.error,
    this.failed = false,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        body = Map<String, dynamic>.from(body);

  final String id;
  final String userId;
  final String type;
  final Map<String, dynamic> body;
  final String? filePath;
  final String? dependsOn;
  String? error;
  bool failed;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'body': body,
        'filePath': filePath,
        'dependsOn': dependsOn,
        'error': error,
        'failed': failed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedJob.fromJson(Map<String, dynamic> json) {
    final rawBody = json['body'];
    return QueuedJob(
      id: '${json['id']}',
      userId: '${json['userId']}',
      type: '${json['type']}',
      body: rawBody is Map ? Map<String, dynamic>.from(rawBody) : <String, dynamic>{},
      filePath: json['filePath'] as String?,
      dependsOn: json['dependsOn'] as String?,
      error: json['error'] as String?,
      failed: json['failed'] == true,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

class OfflineQueue {
  OfflineQueue([List<QueuedJob>? jobs]) : jobs = jobs ?? <QueuedJob>[];

  final List<QueuedJob> jobs;
  int _seq = 0;

  String nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  void add(QueuedJob job) => jobs.add(job);

  void remove(String id) => jobs.removeWhere((job) => job.id == id);

  int pendingFor(String userId) =>
      jobs.where((job) => job.userId == userId && !job.failed).length;

  int failedFor(String userId) =>
      jobs.where((job) => job.userId == userId && job.failed).length;

  /// Last unsynced punch for this user: `in`, `out`, or null.
  String? pendingPunch(String userId) {
    String? last;
    for (final job in jobs) {
      if (job.userId != userId || job.failed) continue;
      if (job.type == 'punch_in') last = 'in';
      if (job.type == 'punch_out') last = 'out';
    }
    return last;
  }

  /// Jobs that can be sent now. A visit complete waits for its create.
  List<QueuedJob> ready() {
    final waiting = jobs.where((job) => !job.failed).map((job) => job.id).toSet();
    return jobs.where((job) {
      if (job.failed) return false;
      final dependsOn = job.dependsOn;
      if (dependsOn == null) return true;
      return !waiting.contains(dependsOn);
    }).toList();
  }

  void markFailed(String id, String message) {
    for (final job in jobs) {
      if (job.id == id) {
        job.failed = true;
        job.error = message;
      }
    }
    for (final job in jobs) {
      if (job.dependsOn == id && !job.failed) {
        job.failed = true;
        job.error = message;
      }
    }
  }

  void discardFailed(String userId) {
    jobs.removeWhere((job) => job.userId == userId && job.failed);
  }

  String encode() => jsonEncode(toJsonList());

  List<Map<String, dynamic>> toJsonList() => jobs.map((job) => job.toJson()).toList();

  factory OfflineQueue.decode(String? raw) {
    if (raw == null || raw.isEmpty) return OfflineQueue();
    final parsed = jsonDecode(raw);
    if (parsed is! List) return OfflineQueue();
    final jobs = parsed
        .whereType<Map>()
        .map((item) => QueuedJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return OfflineQueue(jobs);
  }
}
