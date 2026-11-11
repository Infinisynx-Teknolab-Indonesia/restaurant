import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:resto_core/resto_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lebar kertas struk (mm): 58 atau 80. Disimpan di pengaturan Akun.
Future<int> paperWidth() async => (await SharedPreferences.getInstance()).getInt('paper') ?? 58;
Future<void> setPaperWidth(int mm) async => (await SharedPreferences.getInstance()).setInt('paper', mm);
Future<bool> autoPrint() async => (await SharedPreferences.getInstance()).getBool('auto_print') ?? true;
Future<void> setAutoPrint(bool v) async => (await SharedPreferences.getInstance()).setBool('auto_print', v);

String _n(dynamic v) => uang(v is num ? v : num.tryParse('$v') ?? 0);

Future<Uint8List> buildReceiptPdf(Map<String, dynamic> bill, {int widthMm = 58}) async {
  final doc = pw.Document();
  final r = Map<String, dynamic>.from(bill['restaurant']);
  final o = Map<String, dynamic>.from(bill['order']);
  final lines = (bill['lines'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  final pays = (bill['payments'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  final paid = bill['is_paid'] == true;
  final small = widthMm <= 58;
  final fs = small ? 7.5 : 9.0;
  final st = pw.TextStyle(fontSize: fs);
  final bold = pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold);

  pw.Widget lr(String a, String b, {pw.TextStyle? style}) => pw.Row(children: [
        pw.Expanded(child: pw.Text(tr(a), style: style ?? st)),
        pw.Text(b, style: style ?? st),
      ]);
  pw.Widget dash() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text('-' * (small ? 40 : 56), style: st, maxLines: 1, overflow: pw.TextOverflow.clip),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat(widthMm * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('${r['name']}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs + 3, fontWeight: pw.FontWeight.bold)),
      pw.Text('${r['address']}', textAlign: pw.TextAlign.center, style: st),
      pw.Text('${r['phone']}', textAlign: pw.TextAlign.center, style: st),
      dash(),
      lr('No', '${o['code']}'),
      lr('Tanggal', tanggalJam('${o['created_at']}')),
      if (o['table_number'] != null) lr('Meja', '${o['table_number']}'),
      lr('Tipe', orderTypeLabel['${o['order_type']}'] ?? ''),
      if ('${o['customer_name'] ?? ''}'.isNotEmpty) lr('Pelanggan', '${o['customer_name']}'),
      if (o['waiter_name'] != null) lr('Pelayan', '${o['waiter_name']}'),
      dash(),
      for (final l in lines) ...[
        pw.Text('${l['name']}', style: st),
        lr('  ${l['qty']} x ${_n(l['price'])}', _n(l['amount'])),
        if ('${l['notes'] ?? ''}'.isNotEmpty) pw.Text('  *${l['notes']}', style: pw.TextStyle(fontSize: fs - 1, fontStyle: pw.FontStyle.italic)),
      ],
      dash(),
      lr('Subtotal', _n(o['subtotal'])),
      if ((o['voucher_discount'] ?? 0) != 0) lr('Voucher ${o['voucher_code']}', '-${_n(o['voucher_discount'])}'),
      if ((o['other_discount'] ?? 0) != 0) lr('Diskon/Poin', '-${_n(o['other_discount'])}'),
      if ((o['service'] ?? 0) != 0) lr('Service ${r['service_percent']}%', _n(o['service'])),
      if ((o['tax'] ?? 0) != 0) lr('PB1 ${r['tax_percent']}%', _n(o['tax'])),
      if ((bill['delivery_fee'] ?? 0) != 0) lr('Ongkir', _n(bill['delivery_fee'])),
      if ((bill['delivery_fee'] ?? 0) == 0 && bill['free_delivery'] == true) lr('Ongkir', 'GRATIS'),
      pw.SizedBox(height: 2),
      lr('TOTAL', _n(o['total']), style: pw.TextStyle(fontSize: fs + 2, fontWeight: pw.FontWeight.bold)),
      for (final p in pays) ...[
        lr('Bayar ${methodLabel['${p['method']}'] ?? p['method']}', _n((p['paid_amount'] ?? 0) != 0 ? p['paid_amount'] : p['amount'])),
        if ((p['change_amount'] ?? 0) != 0) lr('Kembali', _n(p['change_amount']), style: bold),
        if ('${p['reference'] ?? ''}'.isNotEmpty && p['method'] != 'cash') lr('Ref', '${p['reference']}'),
      ],
      if (!paid) ...[dash(), pw.Text('** BELUM DIBAYAR **', textAlign: pw.TextAlign.center, style: bold)],
      if ((o['points_earned'] ?? 0) != 0) pw.Text('Poin didapat: +${o['points_earned']}', textAlign: pw.TextAlign.center, style: st),
      dash(),
      pw.Text('${r['footer']}', textAlign: pw.TextAlign.center, style: st),
      pw.SizedBox(height: 10),
    ]),
  ));
  return doc.save();
}

/// Cetak struk/bill pesanan lewat printer sistem (Wi-Fi/Bluetooth/USB yang terdaftar di Android/iOS).
Future<void> printBill(BuildContext context, int orderId) async {
  try {
    final bill = Map<String, dynamic>.from(await api.get('/api/orders/$orderId/bill'));
    final w = await paperWidth();
    final bytes = await buildReceiptPdf(bill, widthMm: w);
    await Printing.layoutPdf(
      name: 'Struk ${bill['order']['code']}',
      format: PdfPageFormat(w * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
      onLayout: (_) async => bytes,
    );
  } catch (e) {
    if (context.mounted) showSnack(context, 'Gagal cetak: $e', error: true);
  }
}

/// Bagikan struk PDF (WhatsApp, email, dll).
Future<void> shareBill(BuildContext context, int orderId) async {
  try {
    final bill = Map<String, dynamic>.from(await api.get('/api/orders/$orderId/bill'));
    final bytes = await buildReceiptPdf(bill, widthMm: await paperWidth());
    await Printing.sharePdf(bytes: bytes, filename: 'struk_${bill['order']['code']}.pdf');
  } catch (e) {
    if (context.mounted) showSnack(context, 'Gagal membagikan: $e', error: true);
  }
}
