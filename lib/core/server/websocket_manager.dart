import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Server-side WebSocket connection manager.
/// Maintains the set of connected clients and broadcasts events to all of them.
class WebSocketManager {
  static final WebSocketManager instance = WebSocketManager._();
  WebSocketManager._();

  final Set<WebSocketChannel> _clients = {};

  final _localController = StreamController<Map<String, dynamic>>.broadcast();

  /// In-process event stream. The server device listens here to get
  /// the same events that are pushed to remote WebSocket clients.
  Stream<Map<String, dynamic>> get localEvents => _localController.stream;

  int get clientCount => _clients.length;

  void addClient(WebSocketChannel channel) {
    _clients.add(channel);
    debugPrint('[WS Server] Client connected. Total: ${_clients.length}');

    channel.stream.listen(
      (_) {}, // server ignores client messages
      onDone: () {
        _clients.remove(channel);
        debugPrint('[WS Server] Client disconnected. Total: ${_clients.length}');
      },
      onError: (_) {
        _clients.remove(channel);
      },
      cancelOnError: true,
    );
  }

  /// Broadcast an event to all connected WebSocket clients.
  /// [event] — event name, e.g. 'tables_updated', 'order_updated'
  /// [data]  — optional additional payload fields
  void broadcast(String event, [Map<String, dynamic>? data]) {
    final eventMap = {
      'event': event,
      'ts': DateTime.now().millisecondsSinceEpoch,
      ...?data,
    };

    // Notify in-process listeners (server device's own UI)
    _localController.add(eventMap);

    if (_clients.isEmpty) return;

    final payload = jsonEncode(eventMap);
    final dead = <WebSocketChannel>[];
    for (final client in _clients) {
      try {
        client.sink.add(payload);
      } catch (_) {
        dead.add(client);
      }
    }
    _clients.removeAll(dead);
  }

  void closeAll() {
    for (final client in _clients) {
      try {
        client.sink.close();
      } catch (_) {}
    }
    _clients.clear();
  }
}
