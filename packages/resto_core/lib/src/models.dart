import 'format.dart';

int _i(dynamic v) => v == null ? 0 : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0));
String _s(dynamic v) => v == null ? '' : '$v';
bool _b(dynamic v) => v == true || v == 1 || v == 'true';

class AppUser {
  final int id;
  final String name;
  final String? username, email, phone, birthday, address, position;
  final String role;
  final int points, lifetimePoints;
  final String tier;

  AppUser({
    required this.id, required this.name, required this.role, this.username, this.email,
    this.phone, this.birthday, this.address, this.position, this.points = 0,
    this.lifetimePoints = 0, this.tier = 'Bronze',
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']), name: _s(j['name']), role: _s(j['role']),
        username: j['username'], email: j['email'], phone: j['phone'],
        birthday: j['birthday'], address: j['address'], position: j['position'],
        points: _i(j['points']), lifetimePoints: _i(j['lifetime_points']),
        tier: j['tier'] ?? 'Bronze',
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'role': role, 'username': username, 'email': email,
        'phone': phone, 'birthday': birthday, 'address': address, 'position': position,
        'points': points, 'lifetime_points': lifetimePoints, 'tier': tier,
      };

  bool get isCashier => role == 'cashier' || isSupervisor;
  bool get isWaiter => role == 'waiter' || role == 'manager' || role == 'admin';
  /// Pengawas / Manager / Admin — boleh koreksi pesanan yang SUDAH DIBAYAR.
  bool get isSupervisor => role == 'supervisor' || role == 'manager' || role == 'admin';

  /// Aturan edit pesanan:
  /// - belum dikirim (draft di HP waiter): bebas diedit & dicek ulang
  /// - sudah dikirim ke dapur: hanya Kasir (atau Pengawas)
  /// - sudah dibayar: hanya Pengawas
  /// Semua koreksi wajib alasan & dilaporkan ke Admin.
  bool canEditOrder(Order o) {
    if (o.isClosed && !o.isPaid) return false;
    if (o.status == 'cancelled') return false;
    return o.isPaid ? isSupervisor : isCashier;
  }
}

class RestoInfo {
  final String name, address, phone, openHours, footer, paymentGateway;
  final int taxPercent, servicePercent, pointsPerAmount, pointValue, minRedeem, deliveryFee;
  final int tierSilver, tierGold;
  /// Mata uang restoran (Rp / US$ / S$ / RM) & apakah QRIS tersedia (hanya IDR).
  final Map<String, dynamic>? currency;
  final bool qrisAvailable;
  /// Tentang Kami & Hubungi Kami (diatur Admin › Pengaturan).
  final String aboutText, contactWhatsapp, contactInstagram;
  final bool contactEnabled;

  RestoInfo({
    this.currency, this.qrisAvailable = true,
    this.aboutText = '', this.contactEnabled = false, this.contactWhatsapp = '', this.contactInstagram = '',
    required this.name, required this.address, required this.phone, required this.openHours,
    required this.footer, required this.paymentGateway, required this.taxPercent,
    required this.servicePercent, required this.pointsPerAmount, required this.pointValue,
    required this.minRedeem, required this.deliveryFee, required this.tierSilver, required this.tierGold,
  });

  factory RestoInfo.fromJson(Map<String, dynamic> j) => RestoInfo(
        name: _s(j['restaurant_name']), address: _s(j['address']), phone: _s(j['phone']),
        openHours: _s(j['open_hours']), footer: _s(j['receipt_footer']),
        paymentGateway: _s(j['payment_gateway']), taxPercent: _i(j['tax_percent']),
        servicePercent: _i(j['service_percent']), pointsPerAmount: _i(j['points_per_amount']),
        pointValue: _i(j['point_value']), minRedeem: _i(j['min_redeem_points']),
        deliveryFee: _i(j['delivery_fee']), tierSilver: _i(j['tier_silver']), tierGold: _i(j['tier_gold']),
        currency: j['currency'] == null ? null : Map<String, dynamic>.from(j['currency']),
        qrisAvailable: j['qris_available'] != false,
        aboutText: _s(j['about_text']), contactEnabled: j['contact_enabled'] == true,
        contactWhatsapp: _s(j['contact_whatsapp']), contactInstagram: _s(j['contact_instagram']),
      );
}

class MenuCategory {
  final int id;
  final String name, icon, kind; // kind: food | drink
  final List<MenuItem> items;
  MenuCategory({required this.id, required this.name, required this.icon, required this.items, this.kind = 'food'});

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: _i(j['id']), name: _s(j['name']), icon: _s(j['icon']),
        kind: j['kind'] == null || '${j['kind']}'.isEmpty ? 'food' : '${j['kind']}',
        items: ((j['items'] ?? []) as List).map((e) => MenuItem.fromJson(e)).toList(),
      );
}

class MenuItem {
  final int id, categoryId, price;
  final String name, description, imageUrl, station, categoryName;
  final bool isAvailable, isRecommended;
  final int? stock;

  MenuItem({
    required this.id, required this.categoryId, required this.price, required this.name,
    required this.description, required this.imageUrl, required this.station,
    required this.categoryName, required this.isAvailable, required this.isRecommended, this.stock,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: _i(j['id']), categoryId: _i(j['category_id']), price: _i(j['price']),
        name: _s(j['name']), description: _s(j['description']), imageUrl: _s(j['image_url']),
        station: _s(j['station']), categoryName: _s(j['category_name']),
        isAvailable: _b(j['is_available']), isRecommended: _b(j['is_recommended']),
        stock: j['stock'] == null ? null : _i(j['stock']),
      );
}

class DiningTable {
  final int id, seats;
  final String number, area, status;
  final List<Map<String, dynamic>> openOrders;
  DiningTable({required this.id, required this.seats, required this.number, required this.area,
      required this.status, required this.openOrders});

  factory DiningTable.fromJson(Map<String, dynamic> j) => DiningTable(
        id: _i(j['id']), seats: _i(j['seats']), number: _s(j['number']), area: _s(j['area']),
        status: _s(j['status']),
        openOrders: ((j['open_orders'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      );

  int get openTotal => openOrders.fold(0, (s, o) => s + _i(o['total']));
}

class OrderItem {
  final int id, menuItemId, price, qty;
  final String name, notes, station, status, createdAt;
  /// Catatan koreksi dari kasir/pengawas (tampil di dapur & daftar pesanan).
  final String editNote;
  OrderItem({required this.id, required this.menuItemId, required this.price, required this.qty,
      required this.name, required this.notes, required this.station, required this.status,
      required this.createdAt, this.editNote = ''});

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: _i(j['id']), menuItemId: _i(j['menu_item_id']), price: _i(j['price']), qty: _i(j['qty']),
        name: _s(j['name']), notes: _s(j['notes']), station: _s(j['station']), status: _s(j['status']),
        createdAt: _s(j['created_at']), editNote: _s(j['edit_note']),
      );

  int get amount => price * qty;
  bool get isVoid => status == 'void';
}

class Order {
  final int id;
  final String code, orderType, source, status, paymentStatus;
  final int? tableId, customerId, waiterId;
  final String? tableNumber, waiterName, customerPhone;
  final String customerName, notes, deliveryAddress, createdAt;
  final String? paidAt;
  final int subtotal, discount, extraDiscount, service, tax, total, pointsUsed, pointsEarned;
  final int voucherDiscount, otherDiscount, deliveryFee;
  final String voucherCode, voucherName, voucherType;
  final List<OrderItem> items;

  Order({
    required this.id, required this.code, required this.orderType, required this.source,
    required this.status, required this.paymentStatus, this.tableId, this.customerId, this.waiterId,
    this.tableNumber, this.waiterName, this.customerPhone, required this.customerName,
    required this.notes, required this.deliveryAddress, required this.createdAt, this.paidAt,
    required this.subtotal, required this.discount, required this.extraDiscount, required this.service,
    required this.tax, required this.total, required this.pointsUsed, required this.pointsEarned,
    required this.items, this.voucherDiscount = 0, this.otherDiscount = 0, this.deliveryFee = 0,
    this.voucherCode = '', this.voucherName = '', this.voucherType = '',
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _i(j['id']), code: _s(j['code']), orderType: _s(j['order_type']), source: _s(j['source']),
        status: _s(j['status']), paymentStatus: _s(j['payment_status']),
        tableId: j['table_id'] == null ? null : _i(j['table_id']),
        customerId: j['customer_id'] == null ? null : _i(j['customer_id']),
        waiterId: j['waiter_id'] == null ? null : _i(j['waiter_id']),
        tableNumber: j['table_number']?.toString(), waiterName: j['waiter_name'],
        customerPhone: j['customer_phone'], customerName: _s(j['customer_name']),
        notes: _s(j['notes']), deliveryAddress: _s(j['delivery_address']),
        createdAt: _s(j['created_at']), paidAt: j['paid_at'],
        subtotal: _i(j['subtotal']), discount: _i(j['discount']), extraDiscount: _i(j['extra_discount']),
        service: _i(j['service']), tax: _i(j['tax']), total: _i(j['total']),
        pointsUsed: _i(j['points_used']), pointsEarned: _i(j['points_earned']),
        items: ((j['items'] ?? []) as List).map((e) => OrderItem.fromJson(e)).toList(),
        voucherDiscount: _i(j['voucher_discount']), otherDiscount: _i(j['other_discount']),
        deliveryFee: _i(j['delivery_fee']), voucherCode: _s(j['voucher_code']),
        voucherName: _s(j['voucher_name']), voucherType: _s(j['voucher_type']),
      );

  bool get hasVoucher => voucherCode.isNotEmpty;
  bool get freeDelivery => voucherType == 'free_delivery';
  bool get isPaid => paymentStatus == 'paid';
  bool get isClosed => status == 'completed' || status == 'cancelled';
  List<OrderItem> get activeItems => items.where((i) => !i.isVoid).toList();
  String get title => tableNumber != null ? 'Meja $tableNumber' : (orderTypeLabel[orderType] ?? orderType);
}

class Payment {
  final int id, orderId, amount, paidAmount, changeAmount;
  final String method, status, reference, gateway, qrString, payUrl;
  final String? orderCode;
  Payment({required this.id, required this.orderId, required this.amount, required this.paidAmount,
      required this.changeAmount, required this.method, required this.status, required this.reference,
      required this.gateway, required this.qrString, required this.payUrl, this.orderCode});

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: _i(j['id']), orderId: _i(j['order_id']), amount: _i(j['amount']),
        paidAmount: _i(j['paid_amount']), changeAmount: _i(j['change_amount']),
        method: _s(j['method']), status: _s(j['status']), reference: _s(j['reference']),
        gateway: _s(j['gateway']), qrString: _s(j['qr_string']), payUrl: _s(j['pay_url']),
        orderCode: j['order_code'],
      );

  bool get isPaid => status == 'paid';
}

class Voucher {
  final int id, value, maxDiscount, minSpend, quota, used, perUserLimit, pointsCost, validityDays;
  final int? remaining;
  final String code, name, description, terms, kind, discountType, valueLabel, color;
  final String channel, minTier, orderTypes, days, timeStart, timeEnd;
  final String? startAt, endAt, blockedReason, note;
  final bool newMemberOnly;
  final List<String> autoTerms, categoryNames;

  Voucher({
    required this.id, required this.value, required this.maxDiscount, required this.minSpend,
    required this.quota, required this.used, required this.perUserLimit, required this.pointsCost,
    required this.validityDays, this.remaining, required this.code, required this.name,
    required this.description, required this.terms, required this.kind, required this.discountType,
    required this.valueLabel, required this.color, required this.channel, required this.minTier,
    required this.orderTypes, required this.days, required this.timeStart, required this.timeEnd,
    this.startAt, this.endAt, this.blockedReason, this.note, required this.newMemberOnly,
    required this.autoTerms, required this.categoryNames,
  });

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        id: _i(j['id']), value: _i(j['value']), maxDiscount: _i(j['max_discount']), minSpend: _i(j['min_spend']),
        quota: _i(j['quota']), used: _i(j['used']), perUserLimit: _i(j['per_user_limit']),
        pointsCost: _i(j['points_cost']), validityDays: _i(j['validity_days']),
        remaining: j['remaining'] == null ? null : _i(j['remaining']),
        code: _s(j['code']), name: _s(j['name']), description: _s(j['description']), terms: _s(j['terms']),
        kind: _s(j['kind']), discountType: _s(j['discount_type']), valueLabel: _s(j['value_label']),
        color: j['color'] == null || '${j['color']}'.isEmpty ? '#C5A059' : '${j['color']}',
        channel: _s(j['channel']), minTier: _s(j['min_tier']), orderTypes: _s(j['order_types']),
        days: _s(j['days']), timeStart: _s(j['time_start']), timeEnd: _s(j['time_end']),
        startAt: j['start_at'], endAt: j['end_at'], blockedReason: j['blocked_reason'], note: j['note'],
        newMemberOnly: _b(j['new_member_only']),
        autoTerms: ((j['auto_terms'] ?? []) as List).map((e) => '$e').toList(),
        categoryNames: ((j['category_names'] ?? []) as List).map((e) => '$e').toList(),
      );

  /// Semua S&K: otomatis dari pengaturan + tambahan dari admin.
  List<String> get allTerms => [...autoTerms, ...terms.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty)];

  /// Teks besar di tiket: "20%", "Rp25rb", "Gratis".
  String get bigLabel {
    if (discountType == 'percent') return '$value%';
    if (discountType == 'free_delivery') return 'Gratis';
    final c = Currency.active;
    if (c.code == 'IDR' && value >= 1000 && value % 1000 == 0) return 'Rp${value ~/ 1000}rb';
    return c.format(value);
  }

  String get smallLabel => discountType == 'percent' ? 'DISKON' : discountType == 'free_delivery' ? 'ONGKIR' : 'POTONGAN';
}

class WalletVoucher {
  final int id;
  final String code, status, source;
  final String? expiresAt, createdAt, usedAt;
  final Voucher voucher;
  WalletVoucher({required this.id, required this.code, required this.status, required this.source,
      this.expiresAt, this.createdAt, this.usedAt, required this.voucher});
  factory WalletVoucher.fromJson(Map<String, dynamic> j) => WalletVoucher(
      id: _i(j['id']), code: _s(j['code']), status: _s(j['status']), source: _s(j['source']),
      expiresAt: j['expires_at'], createdAt: j['created_at'], usedAt: j['used_at'],
      voucher: Voucher.fromJson(Map<String, dynamic>.from(j['voucher'])));
  bool get isActive => status == 'active';
}

/// Hasil cek voucher di keranjang.
class VoucherCheck {
  final bool ok, freeDelivery;
  final String message, code;
  final int discount, deliverySaving;
  final Voucher voucher;
  VoucherCheck({required this.ok, required this.freeDelivery, required this.message, required this.code,
      required this.discount, required this.deliverySaving, required this.voucher});
  factory VoucherCheck.fromJson(Map<String, dynamic> j) => VoucherCheck(
      ok: _b(j['ok']), freeDelivery: _b(j['free_delivery']), message: _s(j['message']), code: _s(j['code']),
      discount: _i(j['discount']), deliverySaving: _i(j['delivery_saving']),
      voucher: Voucher.fromJson(Map<String, dynamic>.from(j['voucher'])));
}

class LoyaltyTx {
  final int id, points;
  final String type, note, createdAt;
  LoyaltyTx({required this.id, required this.points, required this.type, required this.note, required this.createdAt});
  factory LoyaltyTx.fromJson(Map<String, dynamic> j) => LoyaltyTx(
      id: _i(j['id']), points: _i(j['points']), type: _s(j['type']), note: _s(j['note']), createdAt: _s(j['created_at']));
}

class LoyaltyInfo {
  final int points, lifetimePoints, pointsToNext, pointValue, pointsPerAmount, minRedeem;
  final String tier;
  final String? nextTier;
  final List<LoyaltyTx> history;
  LoyaltyInfo({required this.points, required this.lifetimePoints, required this.pointsToNext,
      required this.pointValue, required this.pointsPerAmount, required this.minRedeem, required this.tier,
      this.nextTier, required this.history});
  factory LoyaltyInfo.fromJson(Map<String, dynamic> j) => LoyaltyInfo(
        points: _i(j['points']), lifetimePoints: _i(j['lifetime_points']), pointsToNext: _i(j['points_to_next']),
        pointValue: _i(j['point_value']), pointsPerAmount: _i(j['points_per_amount']),
        minRedeem: _i(j['min_redeem_points']), tier: _s(j['tier']), nextTier: j['next_tier'],
        history: ((j['history'] ?? []) as List).map((e) => LoyaltyTx.fromJson(e)).toList(),
      );
}

/// Hadiah tukar poin (gift card Amazon / Google Play, saldo e-wallet, merchandise) — diatur admin.
class Reward {
  final int id, points;
  final int? available, perMemberLimit;
  final String name, brand, kind, kindLabel, valueLabel, description, terms, color, imageUrl, fulfillment, infoLabel,
      minTier, blockedReason;
  final String? endAt;
  Reward({required this.id, required this.points, this.available, this.perMemberLimit, required this.name,
      required this.brand, required this.kind, required this.kindLabel, required this.valueLabel,
      required this.description, required this.terms, required this.color, required this.imageUrl,
      required this.fulfillment, required this.infoLabel, required this.minTier, required this.blockedReason,
      this.endAt});

  bool get autoCode => fulfillment == 'auto_code';
  bool get canRedeem => blockedReason.isEmpty;

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: _i(j['id']), points: _i(j['points']),
        available: j['available'] == null ? null : _i(j['available']),
        perMemberLimit: j['per_member_limit'] == null ? null : _i(j['per_member_limit']),
        name: _s(j['name']), brand: _s(j['brand']), kind: _s(j['kind']), kindLabel: _s(j['kind_label']),
        valueLabel: _s(j['value_label']), description: _s(j['description']), terms: _s(j['terms']),
        color: _s(j['color']).isEmpty ? '#1F2D4F' : _s(j['color']), imageUrl: _s(j['image_url']),
        fulfillment: _s(j['fulfillment']), infoLabel: _s(j['info_label']), minTier: _s(j['min_tier']),
        blockedReason: _s(j['blocked_reason']), endAt: j['end_at'] as String?,
      );
}

/// Riwayat penukaran poin → hadiah milik member.
class RewardRedemption {
  final int id, rewardId, points;
  final String rewardName, status, statusLabel, info, code, pin, adminNote, brand, valueLabel, color, kind, createdAt;
  final String? completedAt;
  RewardRedemption({required this.id, required this.rewardId, required this.points, required this.rewardName,
      required this.status, required this.statusLabel, required this.info, required this.code, required this.pin,
      required this.adminNote, required this.brand, required this.valueLabel, required this.color,
      required this.kind, required this.createdAt, this.completedAt});

  bool get done => status == 'completed';
  bool get open => status == 'pending' || status == 'processing';

  factory RewardRedemption.fromJson(Map<String, dynamic> j) => RewardRedemption(
        id: _i(j['id']), rewardId: _i(j['reward_id']), points: _i(j['points']), rewardName: _s(j['reward_name']),
        status: _s(j['status']), statusLabel: _s(j['status_label']), info: _s(j['info']), code: _s(j['code']),
        pin: _s(j['pin']), adminNote: _s(j['admin_note']), brand: _s(j['brand']), valueLabel: _s(j['value_label']),
        color: _s(j['color']).isEmpty ? '#1F2D4F' : _s(j['color']), kind: _s(j['kind']),
        createdAt: _s(j['created_at']), completedAt: j['completed_at'] as String?,
      );
}
