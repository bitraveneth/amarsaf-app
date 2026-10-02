import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class CatalogItem {
  const CatalogItem({required this.id, required this.name, required this.sku, required this.price});

  final int id;
  final String name;
  final String sku;
  final double price;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: asInt(json['id']),
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      price: asDouble(json['effective_price'] ?? json['base_price']),
    );
  }
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.forEmployee});

  final bool forEmployee;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _search = TextEditingController();
  final _notes = TextEditingController();
  final _dealerSearch = TextEditingController();
  List<Map<String, dynamic>> _agents = [];
  int? _agentId;
  String _orderType = 'regular';
  List<CatalogItem> _products = [];
  int _page = 1;
  int _lastPage = 1;
  final Map<int, int> _qty = {};
  final Map<int, double> _prices = {};
  bool _loadingAgents = false;
  bool _loadingProducts = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.forEmployee) {
      _loadAgents();
    } else {
      _loadProducts(reset: true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    _dealerSearch.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _loadingAgents = true);
    final state = context.read<AppState>();
    final all = <Map<String, dynamic>>[];
    try {
      var page = 1;
      while (page <= 8) {
        final response = await state.fetch('/employee/agents', query: {'page': '$page'});
        final data = response['data'];
        if (data is List) {
          all.addAll(data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
        }
        if (asInt(response['last_page']) <= page) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _agents = all;
        _loadingAgents = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingAgents = false;
      });
    }
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (widget.forEmployee && _agentId == null) return;
    final nextPage = reset ? 1 : _page + 1;
    setState(() => _loadingProducts = true);
    try {
      final path = widget.forEmployee ? '/employee/agents/$_agentId/products' : '/agent/products';
      final response = await context.read<AppState>().fetch(path, query: {
        'search': _search.text.trim(),
        'per_page': '20',
        'page': '$nextPage',
      });
      final data = response['data'];
      final items = data is List
          ? data.whereType<Map>().map((item) => CatalogItem.fromJson(Map<String, dynamic>.from(item))).toList()
          : <CatalogItem>[];
      if (!mounted) return;
      setState(() {
        _page = asInt(response['current_page']) == 0 ? nextPage : asInt(response['current_page']);
        _lastPage = asInt(response['last_page']) == 0 ? 1 : asInt(response['last_page']);
        _products = reset ? items : [..._products, ...items];
        _loadingProducts = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingProducts = false;
      });
    }
  }

  void _changeQty(CatalogItem item, int delta) {
    final next = (_qty[item.id] ?? 0) + delta;
    setState(() {
      _prices[item.id] = item.price;
      if (next <= 0) {
        _qty.remove(item.id);
      } else {
        _qty[item.id] = next;
      }
    });
  }

  Future<void> _place() async {
    final state = context.read<AppState>();
    if (widget.forEmployee && _agentId == null) {
      setState(() => _error = state.text.pickDealer);
      return;
    }
    if (_qty.isEmpty) {
      setState(() => _error = state.text.addItem);
      return;
    }
    setState(() => _busy = true);
    try {
      final items = _qty.entries.map((entry) => {'product_id': entry.key, 'quantity': entry.value}).toList();
      final result = await state.placeOrder(
        forEmployee: widget.forEmployee,
        agentId: _agentId,
        orderType: _orderType,
        notes: _notes.text,
        items: items,
      );
      if (!mounted) return;
      setState(() => _qty.clear());
      await showNotice(context, result.queued ? state.text.offlineSaved : state.text.orderPlaced);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().text;
    final dealerQuery = _dealerSearch.text.trim().toLowerCase();
    final dealers = _agents.where((agent) {
      if (dealerQuery.isEmpty) return true;
      return '${agent['name']}'.toLowerCase().contains(dealerQuery);
    }).toList();
    final cartTotal = _qty.entries.fold<double>(0, (sum, entry) => sum + (_prices[entry.key] ?? 0) * entry.value);
    final cartCount = _qty.values.fold<int>(0, (sum, qty) => sum + qty);

    return FieldScaffold(
      title: widget.forEmployee ? text.orderForDealer : text.products,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const QueueBanner(),
          if (widget.forEmployee) ...[
            Text(text.zoneNote, style: const TextStyle(color: muted)),
            const SizedBox(height: 8),
            if (_loadingAgents)
              const LinearProgressIndicator()
            else ...[
              TextField(
                controller: _dealerSearch,
                decoration: InputDecoration(labelText: text.searchDealers),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (dealers.isEmpty)
                EmptyNote(text.noDealers)
              else
                SizedBox(
                  height: 148,
                  child: ListView(
                    children: [
                      for (final agent in dealers)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${agent['name']}'),
                          subtitle: Text('${agent['zone'] ?? ''}'),
                          trailing: _agentId == asInt(agent['id']) ? const Icon(Icons.check, color: brand) : null,
                          onTap: () {
                            setState(() => _agentId = asInt(agent['id']));
                            _loadProducts(reset: true);
                          },
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String>(
            initialValue: _orderType,
            decoration: InputDecoration(labelText: text.orderType),
            items: [
              DropdownMenuItem(value: 'regular', child: Text(text.regular)),
              DropdownMenuItem(value: 'bulk', child: Text(text.bulk)),
              DropdownMenuItem(value: 'sample', child: Text(text.sample)),
              DropdownMenuItem(value: 'return', child: Text(text.returnOrder)),
            ],
            onChanged: (value) => setState(() => _orderType = value ?? 'regular'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            decoration: InputDecoration(labelText: text.searchProducts, suffixIcon: const Icon(Icons.search)),
            onSubmitted: (_) => _loadProducts(reset: true),
          ),
          const SizedBox(height: 8),
          if (_loadingProducts && _products.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_products.isEmpty && (widget.forEmployee ? _agentId != null : true))
            EmptyNote(text.noProducts)
          else
            for (final item in _products)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                            Text('${item.sku} · ${taka(item.price)}', style: const TextStyle(color: muted)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => _changeQty(item, -1), icon: const Icon(Icons.remove_circle_outline)),
                      Text('${_qty[item.id] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(onPressed: () => _changeQty(item, 1), icon: const Icon(Icons.add_circle_outline, color: brand)),
                    ],
                  ),
                ),
              ),
          if (_page < _lastPage)
            TextButton(
              onPressed: _loadingProducts ? null : () => _loadProducts(reset: false),
              child: Text(_loadingProducts ? text.loading : text.search),
            ),
          const SizedBox(height: 8),
          TextField(controller: _notes, decoration: InputDecoration(labelText: text.notes), maxLines: 2),
          const SizedBox(height: 8),
          Text(
            cartCount == 0 ? text.emptyCart : '${text.cart}: $cartCount · ${taka(cartTotal)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: clay)),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _place, child: Text(_busy ? text.loading : text.placeOrder)),
        ],
      ),
    );
  }
}
