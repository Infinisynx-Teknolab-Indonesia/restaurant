import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeEvent {
  final String event;
  final Map<String, dynamic> data;
  RealtimeEvent(this.event, this.data);
}

/// Koneksi WebSocket ke server dengan auto-reconnect.
/// Event: order_new, order_updated, order_items_added, order_ready, order_paid,
/// order_pending, payment_paid, menu_changed, table_changed.
class RealtimeService {
  final _ctrl = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _ctrl.stream;
  final ValueNotifier<bool> connected = ValueNotifier(false);

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _ping, _retry;
  String? _url;
  bool _closed = true;

  void connect(String baseUrl, String token) {
    disconnect();
    _closed = false;
    final wsBase = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    _url = '$wsBase/ws?token=${Uri.encodeComponent(token)}';
    _open();
  }

  void _open() {
    if (_closed || _url == null) return;
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_url!));
      _ch = ch;
      _sub = ch.stream.listen(
        (msg) {
          connected.value = true;
          try {
            final j = jsonDecode('$msg');
            if (j is Map && j['event'] != null) {
              final ev = '${j['event']}';
              if (ev == 'hello' || ev == 'pong') return;
              final d = j['data'];
              _ctrl.add(RealtimeEvent(ev, d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{}));
            }
          } catch (_) {}
        },
        onDone: _onLost,
        onError: (_) => _onLost(),
        cancelOnError: true,
      );
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ch?.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _onLost();
    }
  }

  void _onLost() {
    connected.value = false;
    _ping?.cancel();
    if (_closed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), _open);
  }

  void disconnect() {
    _closed = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    connected.value = false;
  }
}
