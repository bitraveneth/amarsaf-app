import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_screen.dart';

class SalesHomeScreen extends StatefulWidget {
  const SalesHomeScreen({super.key});

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  Map<String, dynamic>? _dash;
  Map<String, dynamic>? _targets;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      final dash = await state.fetch('/employee/dashboard');
      Map<String, dynamic>? targets;
      try {
        targets = await state.fetch('/employee/targets');
      } catch (_) {
        targets = null;
      }
      if (!mounted) return;
      setState(() {
        _dash = dash;
        _targets = targets;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = state.text;
    return FieldScaffold(
      title: text.salesTitle,
      brandHeader: true,
      actions: [
        IconButton(onPressed: state.logout, icon: const Icon(Icons.logout), tooltip: text.logout),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const QueueBanner(),
            Text('${text.hello}, ${state.displayName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.4)),
            if (state.employee?['work_zone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${state.employee?['work_zone']}', style: const TextStyle(color: muted)),
              ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
            else ...[
              GroupedList(
                children: [
                  GroupedRow(
                    title: text.attendance,
                    subtitle: _attendanceLine(state, text),
                    onTap: () => _open(const PunchScreen()),
                  ),
                  GroupedRow(
                    title: text.taMonth,
                    value: taka(_dash?['ta_this_month']),
                    onTap: () => _open(const AllowanceScreen()),
                  ),
                  GroupedRow(
                    title: text.daMonth,
                    value: taka(_dash?['da_this_month']),
                    onTap: () => _open(const AllowanceScreen()),
                  ),
                  GroupedRow(
                    title: text.openVisits,
                    value: '${asInt(_dash?['open_visits'])}',
                    onTap: () => _open(const VisitsScreen()),
                  ),
                  GroupedRow(
                    title: text.orderForDealer,
                    onTap: () => _open(const OrderScreen(forEmployee: true)),
                  ),
                ],
              ),
              if (_targets != null) ...[
                const SizedBox(height: 16),
                GroupedList(
                  children: [
                    GroupedRow(title: text.targets, value: taka(_targets?['target'])),
                    GroupedRow(title: text.achieved, value: taka(_targets?['achieved'])),
                    GroupedRow(title: text.remaining, value: taka(_targets?['remaining'])),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _attendanceLine(AppState state, L10n text) {
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

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }
}

class PunchScreen extends StatefulWidget {
  const PunchScreen({super.key});

  @override
  State<PunchScreen> createState() => _PunchScreenState();
}

class _PunchScreenState extends State<PunchScreen> {
  bool _busy = false;
  bool _loading = true;
  String? _error;
  PunchSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final state = context.read<AppState>();
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await state.fetch(
        '/employee/location-logs',
        query: const {'limit': '1000'},
      );
      final data = response['data'];
      if (!mounted) return;
      setState(() {
        _summary = summarizePunchLogs(data is List ? data : const []);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    await context.read<AppState>().refreshPunch();
    if (!mounted) return;
    await _load(silent: true);
  }

  Future<void> _punch(bool clockIn) async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final result = await state.punch(clockIn);
      if (!mounted) return;
      await _load(silent: true);
      if (!mounted) return;
      await showNotice(context, result.queued ? state.text.offlineSaved : state.text.saved);
    } on ApiException catch (error) {
      if (mounted) await showNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = state.text;
    final pending = state.queue.pendingPunch(state.userId);
    final onShift = pending == 'in' || (pending == null && state.punchedIn);
    final summary = _summary;
    return FieldScaffold(
      title: text.punch,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const QueueBanner(),
            Text(
              _status(state, text, onShift, pending),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.15,
                color: onShift ? brand : ink,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              onPressed: _busy ? null : () => _punch(!onShift),
              child: Text(_busy ? text.loading : (onShift ? text.punchOut : text.punchIn)),
            ),
            const SizedBox(height: 12),
            Text(text.pingNote, style: const TextStyle(color: muted, height: 1.4, fontSize: 13)),
            const SizedBox(height: 24),
            if (_loading && summary == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && summary == null)
              LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
            else if (summary != null) ...[
              _section(text.today, [
                GroupedRow(title: text.inAt, value: _clock(summary.today.inAt)),
                GroupedRow(title: text.outAt, value: _clock(summary.today.outAt)),
                GroupedRow(title: text.hoursSoFar, value: text.formatHours(summary.today.hours)),
              ]),
              _section(text.yesterday, [
                GroupedRow(title: text.inAt, value: _clock(summary.yesterday.inAt)),
                GroupedRow(title: text.outAt, value: _clock(summary.yesterday.outAt)),
              ]),
              _section(text.thisWeek, [
                GroupedRow(title: text.daysPunched, value: '${summary.weekDays}'),
                GroupedRow(title: text.weekHours, value: text.formatHours(summary.weekHours)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _status(AppState state, L10n text, bool onShift, String? pending) {
    if (pending != null) return text.waitingPunch;
    if (onShift && state.shiftInAt != null) return '${text.inSince} ${formatClock(state.shiftInAt!)}';
    if (onShift) return text.inSince;
    if (state.shiftOutAt != null) return '${text.punchedOut} ${formatClock(state.shiftOutAt!)}';
    return text.notPunched;
  }

  String _clock(DateTime? value) => value == null ? '—' : formatClock(value);

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(title, style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          GroupedList(children: rows),
        ],
      ),
    );
  }
}

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<AppState>().fetch(
        '/employee/visit-plans',
        query: {'date': todayIso()},
      );
      final data = response['data'];
      if (!mounted) return;
      setState(() {
        _visits = data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _complete(Map<String, dynamic> visit, {required bool withGps}) async {
    final state = context.read<AppState>();
    double? lat;
    double? lng;
    try {
      if (withGps) {
        final position = await state.capturePosition();
        lat = position.latitude;
        lng = position.longitude;
      }
      final result = await state.completeVisit(
        planId: asInt(visit['id']),
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      await showNotice(context, result.queued ? state.text.offlineSaved : (withGps ? state.text.gpsSaved : state.text.saved));
      await _load();
    } on ApiException catch (error) {
      if (mounted) await showNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    return FieldScaffold(
      title: text.visits,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddVisitScreen()),
          );
          if (added == true) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(text.addVisit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: [
                      const QueueBanner(),
                      Text(text.today, style: const TextStyle(color: muted)),
                      const SizedBox(height: 8),
                      if (_visits.isEmpty)
                        EmptyNote(text.noVisits)
                      else
                        for (final visit in _visits) _VisitCard(visit: visit, onComplete: _complete),
                    ],
                  ),
                ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.onComplete});

  final Map<String, dynamic> visit;
  final Future<void> Function(Map<String, dynamic> visit, {required bool withGps}) onComplete;

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    final status = '${visit['status'] ?? ''}';
    final done = status == 'visited';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${visit['name'] ?? text.dealer}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink)),
              if (visit['slot'] != null) Text('${visit['slot']}', style: const TextStyle(color: muted)),
              if (visit['notes'] != null && '${visit['notes']}'.isNotEmpty) Text('${visit['notes']}'),
              const SizedBox(height: 6),
              Text(text.statusLabel(status), style: TextStyle(color: done ? muted : ink, fontWeight: FontWeight.w600)),
              if (visit['latitude'] != null)
                Text('${visit['latitude']}, ${visit['longitude']}', style: const TextStyle(color: muted, fontSize: 12)),
              if (!done) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => onComplete(visit, withGps: true),
                  child: Text(text.complete),
                ),
                TextButton(
                  onPressed: () => onComplete(visit, withGps: false),
                  child: Text(text.completeWithoutGps),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddVisitScreen extends StatefulWidget {
  const AddVisitScreen({super.key});

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _search = TextEditingController();
  final _slot = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _agents = [];
  int? _agentId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _search.dispose();
    _slot.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    final state = context.read<AppState>();
    final all = <Map<String, dynamic>>[];
    try {
      var page = 1;
      while (page <= 8) {
        final response = await state.fetch('/employee/agents', query: {'page': '$page'});
        final data = response['data'];
        if (data is List) {
          all.addAll(data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        }
        final last = asInt(response['last_page']);
        if (last <= page) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _agents = all;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (_agentId == null) {
      setState(() => _error = state.text.pickDealer);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await state.addVisit(
        agentId: _agentId!,
        date: todayIso(),
        title: _slot.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      await showNotice(context, result.queued ? state.text.offlineSaved : state.text.visitSaved);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    final query = _search.text.trim().toLowerCase();
    final shown = _agents.where((agent) {
      if (query.isEmpty) return true;
      return '${agent['name']}'.toLowerCase().contains(query);
    }).toList();
    return FieldScaffold(
      title: text.addVisit,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(text.zoneNote, style: const TextStyle(color: muted)),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(labelText: text.searchDealers),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  EmptyNote(text.noDealers)
                else
                  ...shown.map((agent) {
                    final id = asInt(agent['id']);
                    return Card(
                      color: _agentId == id ? fieldFill : card,
                      child: ListTile(
                        title: Text('${agent['name']}'),
                        subtitle: Text('${agent['zone'] ?? agent['area'] ?? ''}'),
                        trailing: _agentId == id ? const Icon(Icons.check, color: ink) : null,
                        onTap: () => setState(() => _agentId = id),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                TextField(controller: _slot, decoration: InputDecoration(labelText: text.slot)),
                const SizedBox(height: 10),
                TextField(controller: _notes, decoration: InputDecoration(labelText: text.notes), maxLines: 2),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: clay)),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? text.loading : text.save)),
              ],
            ),
    );
  }
}

class AllowanceScreen extends StatefulWidget {
  const AllowanceScreen({super.key});

  @override
  State<AllowanceScreen> createState() => _AllowanceScreenState();
}

class _AllowanceScreenState extends State<AllowanceScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = 'TA';
  String _date = todayIso();
  String? _photo;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final response = await context.read<AppState>().fetch('/employee/allowances');
      final data = response['data'];
      if (!mounted) return;
      setState(() {
        _recent = data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(8).toList() : [];
      });
    } catch (_) {}
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (file == null || !mounted) return;
    setState(() => _photo = file.path);
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = state.text.invalidAmount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await state.submitAllowance(
        type: _type,
        date: _date,
        amount: amount,
        description: _note.text,
        photoPath: _photo,
      );
      if (!mounted) return;
      _amount.clear();
      _note.clear();
      setState(() => _photo = null);
      await showNotice(context, result.queued ? state.text.offlineSaved : state.text.claimSaved);
      await _loadRecent();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    return FieldScaffold(
      title: text.allowance,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const QueueBanner(),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'TA', label: Text(text.typeTa)),
              ButtonSegment(value: 'DA', label: Text(text.typeDa)),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: text.amount, prefixText: '৳ '),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(text.date),
            subtitle: Text(_date),
            trailing: const Icon(Icons.calendar_today, color: muted),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = todayIso(picked));
            },
          ),
          TextField(controller: _note, decoration: InputDecoration(labelText: text.description), maxLines: 2),
          const SizedBox(height: 8),
          Text(text.billOptional, style: const TextStyle(color: muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: () => _pick(ImageSource.camera), child: Text(text.takePhoto)),
              TextButton(onPressed: () => _pick(ImageSource.gallery), child: Text(text.choosePhoto)),
            ],
          ),
          if (_photo != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => setState(() => _photo = null), child: Text(text.removePhoto)),
            ),
          if (_photo != null) Text(text.photoAttached, style: const TextStyle(color: ink)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: clay)),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? text.loading : text.submit)),
          const SizedBox(height: 22),
          Text(text.recentBills, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 8),
          if (_recent.isEmpty)
            EmptyNote(text.noBills)
          else
            for (final bill in _recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${bill['type']} · ${taka(bill['amount'])}'),
                subtitle: Text('${bill['date'] ?? ''} · ${text.statusLabel('${bill['status']}')}'),
                trailing: bill['attachment_path'] != null ? const Icon(Icons.attach_file, color: muted) : null,
              ),
        ],
      ),
    );
  }
}
