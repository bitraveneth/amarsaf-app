import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_screen.dart';

class DealerHomeScreen extends StatefulWidget {
  const DealerHomeScreen({super.key});

  @override
  State<DealerHomeScreen> createState() => _DealerHomeScreenState();
}

class _DealerHomeScreenState extends State<DealerHomeScreen> {
  Map<String, dynamic>? _dash;
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
      final dash = await context.read<AppState>().fetch('/agent/dashboard');
      if (!mounted) return;
      setState(() {
        _dash = dash;
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

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = state.text;
    return FieldScaffold(
      title: text.dealerTitle,
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
            if (state.agent?['zone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${state.agent?['zone']}', style: const TextStyle(color: muted)),
              ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
            else
              GroupedList(
                children: [
                  GroupedRow(
                    title: text.dues,
                    value: taka(_dash?['outstanding_balance']),
                    onTap: () => _open(const StatementScreen()),
                  ),
                  GroupedRow(
                    title: text.openOrders,
                    value: '${asInt(_dash?['open_orders'])}',
                    onTap: () => _open(const OrdersScreen()),
                  ),
                  GroupedRow(
                    title: text.deliveredMonth,
                    value: '${asInt(_dash?['delivered_this_month'])}',
                  ),
                  GroupedRow(
                    title: text.products,
                    onTap: () => _open(const OrderScreen(forEmployee: false)),
                  ),
                  GroupedRow(
                    title: text.myOrders,
                    onTap: () => _open(const OrdersScreen()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
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
      final response = await context.read<AppState>().fetch('/agent/orders');
      final data = response['data'];
      if (!mounted) return;
      setState(() {
        _orders = data is List ? data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : [];
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
    final text = context.watch<AppState>().text;
    return FieldScaffold(
      title: text.myOrders,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_orders.isEmpty)
                        EmptyNote(text.noOrders)
                      else
                        for (final order in _orders)
                          Card(
                            child: ListTile(
                              title: Text('#${order['id']} · ${text.orderTypeLabel('${order['order_type']}')}'),
                              subtitle: Text('${order['created_at'] ?? order['delivery_date'] ?? ''}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(taka(order['total']), style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                                  Text(text.statusLabel('${order['status']}'), style: const TextStyle(color: muted, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  Map<String, dynamic>? _statement;
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
      final response = await context.read<AppState>().fetch('/agent/statement');
      if (!mounted) return;
      setState(() {
        _statement = response;
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
    final text = context.watch<AppState>().text;
    final rows = _statement?['rows'];
    final lines = rows is List ? rows.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : <Map<String, dynamic>>[];
    return FieldScaffold(
      title: text.statement,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadError(message: _error!, onRetry: _load, retryLabel: text.retry)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      StatCard(label: text.closingBalance, value: taka(_statement?['closing_balance'])),
                      const SizedBox(height: 8),
                      Text(
                        '${_statement?['from'] ?? ''} – ${_statement?['to'] ?? ''}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 8),
                      if (lines.isEmpty)
                        EmptyNote(text.noStatement)
                      else
                        for (final row in lines)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${row['type']} · ${row['ref'] ?? ''}'),
                            subtitle: Text('${row['date'] ?? ''}'),
                            trailing: Text(taka(row['amount']), style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                          ),
                    ],
                  ),
                ),
    );
  }
}
