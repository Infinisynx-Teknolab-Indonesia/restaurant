import 'package:flutter/material.dart';
import 'package:resto_core/resto_core.dart';

import 'shell.dart';

/// Pesanan yang sudah selesai dimasak → waiter mengantar lalu menandai "sudah diantar".
class ReadyPage extends StatefulWidget {
  const ReadyPage({super.key});
  @override
  State<ReadyPage> createState() => _ReadyPageState();
}

class _ReadyPageState extends State<ReadyPage> {
  List<Order>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    restoTick.addListener(_load);
  }

  @override
  void dispose() {
    restoTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await api.activeOrders();
      if (mounted) {
        setState(() {
          _orders = a.where((o) => o.items.any((i) => i.status == 'done')).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _serve(Order o) async {
    await runSafe(context, () => api.patch('/api/orders/${o.id}/serve'), success: '${o.title} ditandai sudah diantar');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _orders ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Siap Diantar')), actions: [
        const LiveDot(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: _error != null && _orders == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _orders == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: rows.isEmpty
                      ? ListView(children: [SizedBox(height: 120), EmptyView(icon: Icons.room_service_outlined, text: tr('Belum ada pesanan yang siap diantar'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (c, i) {
                            final o = rows[i];
                            final done = o.items.where((x) => x.status == 'done').toList();
                            return AppCard(
                              borderColor: const Color(0xFF7C3AED),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(10)),
                                    child: Text(o.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('${o.code}\n${o.customerName}', style: TextStyle(fontSize: 12, color: c.muted))),
                                  Text(sejak(o.updatedAtOrCreated), style: TextStyle(fontSize: 12, color: c.muted)),
                                ]),
                                const SizedBox(height: 12),
                                for (final it in done)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(children: [
                                      Text('${it.qty}x ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      Expanded(child: Text(it.name, style: const TextStyle(fontSize: 16))),
                                      if (it.notes.isNotEmpty) Text('*${it.notes}', style: TextStyle(fontSize: 12, color: c.muted)),
                                    ]),
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    onPressed: () => _serve(o),
                                    icon: const Icon(Icons.done_all_rounded),
                                    label: Text(tr(o.orderType == 'dine_in' ? 'Sudah Diantar ke Meja' : 'Sudah Diambil Pelanggan')),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
    );
  }
}

extension on Order {
  String get updatedAtOrCreated => createdAt;
}
