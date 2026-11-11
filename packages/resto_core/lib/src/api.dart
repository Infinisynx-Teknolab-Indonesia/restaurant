import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

/// HTTP client tunggal untuk semua aplikasi.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String baseUrl = '';
  String? token;
  void Function()? onUnauthorized;
  final Duration timeout = const Duration(seconds: 20);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final u = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return u;
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return u.replace(queryParameters: {...u.queryParameters, ...q});
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    http.Response res;
    try {
      res = await fn().timeout(timeout);
    } on TimeoutException {
      throw ApiException('Gagal terhubung ke server (timeout)');
    } catch (_) {
      throw ApiException('Gagal terhubung ke server');
    }
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    if (res.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    if (res.statusCode >= 400) {
      String msg = 'Permintaan gagal (${res.statusCode})';
      if (data is Map && data['detail'] != null) {
        msg = data['detail'] is String ? data['detail'] : jsonEncode(data['detail']);
      }
      throw ApiException(msg, res.statusCode);
    }
    return data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body, Map<String, dynamic>? query]) =>
      _send(() => http.post(_uri(path, query), headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => http.put(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> patch(String path, [Object? body, Map<String, dynamic>? query]) =>
      _send(() => http.patch(_uri(path, query), headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.delete(_uri(path, query), headers: _headers));

  String imageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  // ------------------------------------------------------------ typed helpers
  Future<RestoInfo> info() async => RestoInfo.fromJson(await get('/api/info'));

  Future<List<MenuCategory>> menu() async =>
      ((await get('/api/menu')) as List).map((e) => MenuCategory.fromJson(e)).toList();

  Future<List<DiningTable>> tables() async =>
      ((await get('/api/tables')) as List).map((e) => DiningTable.fromJson(e)).toList();

  Future<Order> order(int id) async => Order.fromJson(await get('/api/orders/$id'));

  Future<List<Order>> activeOrders() async =>
      ((await get('/api/orders/active')) as List).map((e) => Order.fromJson(e)).toList();

  Future<List<Order>> myOrders() async =>
      ((await get('/api/orders/my')) as List).map((e) => Order.fromJson(e)).toList();

  Future<List<Order>> kitchenOrders({String station = ''}) async =>
      ((await get('/api/kitchen/orders', query: {'station': station})) as List)
          .map((e) => Order.fromJson(e))
          .toList();

  Future<Order> createOrder(Map<String, dynamic> body) async => Order.fromJson(await post('/api/orders', body));

  Future<Payment> payment(int id) async => Payment.fromJson(await get('/api/payments/$id'));

  Future<bool> ping() async {
    try {
      final r = await get('/api/health');
      return r is Map && r['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}

final api = ApiClient.instance;
