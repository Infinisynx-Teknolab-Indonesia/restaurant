import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'i18n.dart';

final _rp = NumberFormat.decimalPattern('id_ID');

/// Mata uang restoran (diatur di Admin › Pengaturan › Mata Uang; dikirim server lewat /api/info).
/// Nilai uang dari server = bilangan bulat satuan terkecil: IDR = rupiah, USD/SGD/MYR = sen.
class Currency {
  final String code, symbol, thousands, decimal;
  final int decimals;
  final bool space;
  const Currency(this.code, this.symbol, this.decimals, this.thousands, this.decimal, this.space);

  static const idr = Currency('IDR', 'Rp', 0, '.', ',', true);
  static const all = <String, Currency>{
    'IDR': idr,
    'USD': Currency('USD', 'US\$', 2, ',', '.', false),
    'SGD': Currency('SGD', 'S\$', 2, ',', '.', false),
    'MYR': Currency('MYR', 'RM', 2, ',', '.', false),
  };

  /// Mata uang aktif (di-set Session dari info server).
  static Currency active = idr;

  static Currency fromJson(Map<String, dynamic>? j) {
    if (j == null) return idr;
    final base = all['${j['code']}'.toUpperCase()] ?? idr;
    return Currency(base.code, '${j['symbol'] ?? base.symbol}', (j['decimals'] as num?)?.toInt() ?? base.decimals,
        '${j['thousands'] ?? base.thousands}', '${j['decimal'] ?? base.decimal}', j['space'] as bool? ?? base.space);
  }

  int get factor => decimals == 0 ? 1 : (decimals == 1 ? 10 : 100);

  /// 25.000 · 4.50
  String number(num? minor) {
    final v = (minor ?? 0).abs() / factor;
    final fixed = v.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => thousands);
    final out = decimals > 0 ? '$intPart$decimal${parts[1]}' : intPart;
    return (minor ?? 0) < 0 ? '-$out' : out;
  }

  /// Rp 25.000 · US$4.50 · S$4.50 · RM4.50
  String format(num? minor) {
    final n = number(minor);
    final neg = n.startsWith('-');
    return '${neg ? '-' : ''}$symbol${space ? ' ' : ''}${neg ? n.substring(1) : n}';
  }

  /// Teks input kasir ("4.50", "4,50", "25.000") → satuan terkecil.
  int parse(String text) {
    var t = text.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
    if (t.isEmpty) return 0;
    if (decimals == 0) return int.tryParse(t.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
    final last = t.lastIndexOf(RegExp(r'[.,]'));
    if (last >= 0 && t.length - last - 1 <= decimals) {
      t = '${t.substring(0, last).replaceAll(RegExp(r'[.,]'), '')}.${t.substring(last + 1)}';
    } else {
      t = t.replaceAll(RegExp(r'[.,]'), '');
    }
    return ((double.tryParse(t) ?? 0) * factor).round();
  }

  /// Satuan terkecil → teks untuk kolom input (tanpa pemisah ribuan).
  String input(num minor) => decimals == 0 ? '$minor' : (minor / factor).toStringAsFixed(decimals);
}

/// Format uang sesuai mata uang restoran: Rp 25.000 · US$4.50 · S$4.50 · RM4.50
/// (nama fungsi tetap `rupiah` agar kompatibel dengan kode lama)
String rupiah(num? v) => Currency.active.format(v);

/// Angka uang tanpa simbol: 25.000 · 4.50
String uang(num? v) => Currency.active.number(v);

/// Format nominal dalam mata uang tertentu (mis. nilai gift card US$10 walau restoran memakai IDR).
String moneyIn(num? v, String code) => (Currency.all[code.toUpperCase()] ?? Currency.active).format(v);

/// Angka biasa (poin, jumlah): 25.000
String angka(num? v) => _rp.format(v ?? 0);

DateTime? parseDate(String? iso) => iso == null ? null : DateTime.tryParse(iso);

String jam(String? iso) {
  final d = parseDate(iso);
  if (d == null) return '-';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String tanggal(String? iso) {
  final d = parseDate(iso);
  if (d == null) return '-';
  switch (Lang.instance.code) {
    case 'en':
      return '${d.day} ${_month[d.month - 1]} ${d.year}';
    case 'zh':
      return '${d.year}年${d.month}月${d.day}日';
  }
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

String tanggalJam(String? iso) {
  final d = parseDate(iso);
  if (d == null) return '-';
  return '${tanggal(iso)}, ${jam(iso)}';
}

/// "5 mnt lalu"
String sejak(String? iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return tr('baru saja');
  if (diff.inMinutes < 60) return tr('${diff.inMinutes} mnt lalu');
  if (diff.inHours < 24) return tr('${diff.inHours} jam lalu');
  return tanggal(iso);
}

class StatusInfo {
  final String _label;
  final Color color;
  final IconData icon;
  const StatusInfo(this._label, this.color, this.icon);
  /// Label sudah diterjemahkan sesuai bahasa aktif.
  String get label => tr(_label);
}

const orderStatus = <String, StatusInfo>{
  'pending': StatusInfo('Menunggu Bayar', Color(0xFFD97706), Icons.hourglass_top_rounded),
  'confirmed': StatusInfo('Dikonfirmasi', Color(0xFF0284C7), Icons.receipt_long_rounded),
  'preparing': StatusInfo('Sedang Dimasak', Color(0xFFEA580C), Icons.soup_kitchen_rounded),
  'ready': StatusInfo('Siap Diantar', Color(0xFF7C3AED), Icons.room_service_rounded),
  'served': StatusInfo('Sudah Diantar', Color(0xFF2563EB), Icons.restaurant_rounded),
  'completed': StatusInfo('Selesai', Color(0xFF16A34A), Icons.check_circle_rounded),
  'cancelled': StatusInfo('Dibatalkan', Color(0xFFDC2626), Icons.cancel_rounded),
};

const paymentStatus = <String, StatusInfo>{
  'unpaid': StatusInfo('Belum Bayar', Color(0xFFDC2626), Icons.money_off_rounded),
  'paid': StatusInfo('Lunas', Color(0xFF16A34A), Icons.verified_rounded),
  'refunded': StatusInfo('Refund', Color(0xFFD97706), Icons.undo_rounded),
  'pending': StatusInfo('Menunggu', Color(0xFFD97706), Icons.hourglass_top_rounded),
  'expired': StatusInfo('Kedaluwarsa', Color(0xFF64748B), Icons.timer_off_rounded),
  'failed': StatusInfo('Gagal', Color(0xFFDC2626), Icons.error_rounded),
};

const itemStatus = <String, StatusInfo>{
  'queued': StatusInfo('Antri', Color(0xFF64748B), Icons.schedule_rounded),
  'cooking': StatusInfo('Dimasak', Color(0xFFEA580C), Icons.local_fire_department_rounded),
  'done': StatusInfo('Siap', Color(0xFF7C3AED), Icons.done_rounded),
  'served': StatusInfo('Diantar', Color(0xFF16A34A), Icons.done_all_rounded),
  'void': StatusInfo('Void', Color(0xFFDC2626), Icons.block_rounded),
};

const _orderTypeLabel = {'dine_in': 'Dine In', 'takeaway': 'Take Away', 'delivery': 'Delivery'};
const _methodLabel = {'cash': 'Tunai', 'card': 'Kartu', 'qris': 'QRIS', 'online': 'Online'};
const _roleLabel = {
  'admin': 'Admin', 'manager': 'Manager', 'supervisor': 'Pengawas', 'cashier': 'Kasir',
  'waiter': 'Waiter', 'kitchen': 'Kitchen', 'customer': 'Member',
};
const _stationLabel = {'kitchen': 'Dapur', 'bakery': 'Bakery', 'bar': 'Bar'};

/// Ikon kategori dari nama Material Symbols yang disimpan di server.
IconData categoryIcon(String name) {
  switch (name) {
    case 'bakery_dining':
      return Icons.bakery_dining_rounded;
    case 'cake':
      return Icons.cake_rounded;
    case 'local_cafe':
      return Icons.local_cafe_rounded;
    case 'fastfood':
      return Icons.fastfood_rounded;
    case 'icecream':
      return Icons.icecream_rounded;
    case 'local_bar':
      return Icons.local_bar_rounded;
    case 'ramen_dining':
      return Icons.ramen_dining_rounded;
    case 'lunch_dining':
      return Icons.lunch_dining_rounded;
    case 'local_pizza':
      return Icons.local_pizza_rounded;
    case 'emoji_food_beverage':
      return Icons.emoji_food_beverage_rounded;
    default:
      return Icons.restaurant_rounded;
  }
}

Map<String, String> get orderTypeLabel => _orderTypeLabel.map((k, v) => MapEntry(k, tr(v)));
Map<String, String> get methodLabel => _methodLabel.map((k, v) => MapEntry(k, tr(v)));
Map<String, String> get roleLabel => _roleLabel.map((k, v) => MapEntry(k, tr(v)));
Map<String, String> get stationLabel => _stationLabel.map((k, v) => MapEntry(k, tr(v)));
