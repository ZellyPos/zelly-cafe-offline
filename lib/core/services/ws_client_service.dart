import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Client-side WebSocket service with auto-reconnect.
/// Used by waiter/client devices to receive real-time events from the server.
class WsClientService {
  static final WsClientService instance = WsClientService._();
  WsClientService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Listen to this stream for server-pushed events.
  Stream<Map<String, dynamic>> get events => _controller.stream;

  String? _wsUrl;
  bool _shouldConnect = false;
  int _reconnectDelay = 2;

  bool get isConnected => _channel != null;

  /// Connect to [serverBaseUrl] (e.g. 'http://192.168.1.5:8080').
  /// Automatically converts to ws:// and appends /ws path.
  void connect(String serverBaseUrl) {          
    final base = serverBaseUrl.trim();
    _wsUrl = base
        .replaceFirst(RegExp(r'^https'), 'wss')
        .replaceFirst(RegExp(r'^http'), 'ws');
    _wsUrl = '$_wsUrl/ws';
    _shouldConnect = true;
    _reconnectDelay = 2;
    _doConnect();
  }

  void disconnect() {
    _shouldConnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    debugPrint('[WS Client] Disconnected.');
  }

  void _doConnect() {
    if (!_shouldConnect || _wsUrl == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        (raw) {
          try {
            final event = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(event);
          } catch (_) {}
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
      _reconnectDelay = 2;
      debugPrint('[WS Client] Connected to $_wsUrl');

      // Ping every 20s to keep connection alive through NAT/firewalls
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[WS Client] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _channel = null;
    if (!_shouldConnect) return;
    debugPrint('[WS Client] Disconnected. Reconnecting in ${_reconnectDelay}s...');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), _doConnect);
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
