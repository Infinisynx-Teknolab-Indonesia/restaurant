import 'package:flutter/foundation.dart';
import 'package:resto_core/resto_core.dart';

class CartLine {
  final MenuItem item;
  int qty;
  String notes;
  CartLine(this.item, this.qty, this.notes);
  int get amount => item.price * qty;
}

/// Keranjang belanja customer.
class Cart extends ChangeNotifier {
  final Map<int, CartLine> _lines = {};

  /// Kode voucher yang dipilih customer (dipakai saat checkout).
  String? voucherCode;

  void setVoucher(String? code) {
    voucherCode = (code == null || code.trim().isEmpty) ? null : code.trim().toUpperCase();
    notifyListeners();
  }

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;
  int get count => _lines.values.fold(0, (s, l) => s + l.qty);
  int get subtotal => _lines.values.fold(0, (s, l) => s + l.amount);
  int qtyOf(int menuId) => _lines[menuId]?.qty ?? 0;

  void add(MenuItem item, {int qty = 1, String notes = ''}) {
    final l = _lines[item.id];
    if (l == null) {
      _lines[item.id] = CartLine(item, qty, notes);
    } else {
      l.qty = (l.qty + qty).clamp(1, 99);
      if (notes.isNotEmpty) l.notes = notes;
    }
    notifyListeners();
  }

  void setQty(int menuId, int qty) {
    if (qty <= 0) {
      _lines.remove(menuId);
    } else {
      _lines[menuId]?.qty = qty;
    }
    notifyListeners();
  }

  void setNotes(int menuId, String notes) {
    _lines[menuId]?.notes = notes;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    voucherCode = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> toPayload() =>
      lines.map((l) => {'menu_item_id': l.item.id, 'qty': l.qty, 'notes': l.notes}).toList();
}
