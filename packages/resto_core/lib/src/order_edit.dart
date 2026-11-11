import 'package:flutter/material.dart';

import 'animations.dart';
import 'api.dart';
import 'format.dart';
import 'i18n.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Aturan koreksi pesanan (sama dengan server):
/// - Draft (belum dikirim)  : waiter bebas edit & cek ulang sebelum menekan "Pesan & Kirim".
/// - Sudah dikirim ke dapur : hanya Kasir (atau Pengawas) — wajib alasan.
/// - Sudah dibayar          : hanya Pengawas — wajib alasan.
/// Setiap koreksi tercatat dan dikirim realtime ke Admin (menu "Koreksi Pesanan").

String editLockReason(AppUser user, Order o) {
  if (o.status == 'cancelled') return tr('Pesanan sudah dibatalkan');
  if (o.isPaid) return tr('Sudah dibayar — hanya Pengawas yang bisa mengubah');
  return tr('Sudah dikirim ke dapur — minta Kasir untuk mengubah');
}

/// Banner kecil di atas daftar item: menjelaskan siapa yang boleh mengubah pesanan ini.
class EditRuleBanner extends StatelessWidget {
  const EditRuleBanner({super.key, required this.user, required this.order});
  final AppUser user;
  final Order order;
  @override
  Widget build(BuildContext context) {
    final can = user.canEditOrder(order);
    final c = can ? const Color(0xFF0284C7) : const Color(0xFFD97706);
    final text = can
        ? (order.isPaid
            ? tr('Mode Pengawas: koreksi pesanan yang sudah dibayar. Wajib isi alasan, dilaporkan ke Admin.')
            : tr('Mode Kasir: koreksi item yang sudah dikirim. Wajib isi alasan, dilaporkan ke Admin.'))
        : editLockReason(user, order);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(can ? Icons.edit_note_rounded : Icons.lock_rounded, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Baris item pesanan yang sudah dikirim, dengan tombol edit / gembok sesuai role.
class SentItemRow extends StatelessWidget {
  const SentItemRow({super.key, required this.user, required this.order, required this.item, required this.onChanged});
  final AppUser user;
  final Order order;
  final OrderItem item;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final it = item;
    final can = user.canEditOrder(order) && !it.isVoid;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: it.editNote.isNotEmpty ? const Color(0xFFD97706) : context.borderColor),
      ),
      child: Row(children: [
        Text('${it.qty}x', style: TextStyle(fontWeight: FontWeight.w700, decoration: it.isVoid ? TextDecoration.lineThrough : null)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.name, style: TextStyle(decoration: it.isVoid ? TextDecoration.lineThrough : null)),
            if (it.notes.isNotEmpty) Text('* ${it.notes}', style: TextStyle(fontSize: 11.5, color: context.muted)),
            if (it.editNote.isNotEmpty)
              Text('✎ ${it.editNote}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
          ]),
        ),
        StatusChip(itemStatus[it.status]!, small: true),
        if (can)
          IconButton(
            tooltip: tr('Koreksi item'),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              if (await showItemEditSheet(context, order, it)) onChanged();
            },
            icon: Icon(Icons.edit_rounded, size: 18, color: context.cs.primary),
          )
        else if (!it.isVoid)
          Tooltip(
            message: editLockReason(user, order),
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.lock_outline_rounded, size: 16, color: context.muted)),
          ),
      ]),
    );
  }
}

/// Sheet koreksi item: ubah jumlah / catatan / hapus — wajib alasan.
Future<bool> showItemEditSheet(BuildContext context, Order order, OrderItem item) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _ItemEditSheet(order: order, item: item),
  );
  return r ?? false;
}

class _ItemEditSheet extends StatefulWidget {
  const _ItemEditSheet({required this.order, required this.item});
  final Order order;
  final OrderItem item;
  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late int _qty = widget.item.qty;
  late final _notes = TextEditingController(text: widget.item.notes);
  final _reason = TextEditingController();
  bool _busy = false;
  static const _quick = ['Salah input waiter', 'Tamu ganti pesanan', 'Tamu batal', 'Menu habis', 'Komplain tamu'];

  Future<void> _save({bool remove = false}) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) return showSnack(context, tr('Alasan koreksi wajib diisi'), error: true);
    setState(() => _busy = true);
    try {
      final path = '/api/orders/${widget.order.id}/items/${widget.item.id}';
      if (remove) {
        await api.delete(path, query: {'reason': reason});
      } else {
        final body = <String, dynamic>{'reason': reason};
        if (_qty != widget.item.qty) body['qty'] = _qty;
        if (_notes.text.trim() != widget.item.notes) body['notes'] = _notes.text.trim();
        if (body.length == 1) {
          setState(() => _busy = false);
          return showSnack(context, tr('Tidak ada perubahan'), error: true);
        }
        await api.patch(path, body);
      }
      if (!mounted) return;
      showSnack(context, tr('Koreksi tersimpan & dilaporkan ke Admin'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order, it = widget.item;
    final paid = o.isPaid;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Koreksi item'), style: serifStyle(size: 20)),
          const SizedBox(height: 4),
          Text('${o.code} · ${o.title}', style: TextStyle(color: context.muted)),
          const SizedBox(height: 12),
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (paid ? const Color(0xFFDC2626) : const Color(0xFFD97706)).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                paid
                    ? tr('Pesanan SUDAH DIBAYAR. Perubahan nilai akan tercatat sebagai selisih dan dilaporkan ke Admin.')
                    : tr('Pesanan sudah dikirim ke dapur. Dapur akan melihat tanda koreksi. Dilaporkan ke Admin.'),
                style: TextStyle(fontSize: 12.5, color: paid ? const Color(0xFFDC2626) : const Color(0xFFB45309), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            QtyStepper(qty: _qty, min: 1, onChanged: (v) => setState(() => _qty = v)),
          ]),
          if (_qty != it.qty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${it.qty}x → ${_qty}x · ${rupiah((_qty - it.qty) * it.price)}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 12),
          TextField(controller: _notes, decoration: deco(context, tr('Catatan untuk dapur'), icon: Icons.notes_rounded)),
          const SizedBox(height: 12),
          TextField(controller: _reason, decoration: deco(context, tr('Alasan koreksi *'), icon: Icons.report_gmailerrorred_rounded)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _quick)
              ActionChip(label: Text(tr(q)), onPressed: () => setState(() => _reason.text = tr(q))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              onPressed: _busy ? null : () async {
                if (await confirmDialog(context, tr('Hapus item?'), '${it.qty}x ${it.name}', okText: tr('Hapus'), danger: true)) {
                  _save(remove: true);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(tr('Hapus item')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(tr('Simpan koreksi')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Riwayat koreksi sebuah pesanan (kasir / pengawas).
Future<void> showEditHistory(BuildContext context, Order order) async {
  final rows = await runSafe(context, () => api.get('/api/orders/${order.id}/edits'));
  if (rows == null || !context.mounted) return;
  final list = List<Map<String, dynamic>>.from((rows as List).map((e) => Map<String, dynamic>.from(e)));
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), shrinkWrap: true, children: [
      Text(tr('Riwayat Koreksi'), style: serifStyle(size: 20)),
      const SizedBox(height: 8),
      if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(tr('Belum ada koreksi'), textAlign: TextAlign.center)),
      for (final e in list)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(e['stage'] == 'paid' ? Icons.verified_user_rounded : Icons.edit_note_rounded,
              color: e['stage'] == 'paid' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
          title: Text('${tr(e['action_label'] ?? '')} ${e['item_name'] ?? ''}  ${e['before']} → ${e['after']}'),
          subtitle: Text('${e['user_name']} · ${jam(e['created_at'])} · ${e['reason']}'),
          trailing: Text(rupiah(e['diff'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
    ]),
  );
}
