import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

class ChatService {
  static const bool preferWebSocket = bool.fromEnvironment(
    'CHAT_PREFER_WEBSOCKET',
    defaultValue: true,
  );

  static const int wsTimeoutSeconds = int.fromEnvironment(
    'CHAT_WS_TIMEOUT_SECONDS',
    defaultValue: 30,
  );

  static String get webSocketUrl {
    const override = String.fromEnvironment('CHAT_WS_URL');
    if (override.trim().isNotEmpty) return override.trim();

    final api = Uri.parse(ApiService.baseUrl);
    final wsScheme = api.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: '/ws/chat',
    ).toString();
  }

  static Future<Map<String, dynamic>> sendChat({
    required String mode,
    required String message,
    List<Map<String, String>> history = const [],
    String? orderNo,
    String? occasion,
    String? weather,
  }) async {
    if (preferWebSocket) {
      try {
        return await _sendViaWebSocket(
          mode: mode,
          message: message,
          history: history,
          orderNo: orderNo,
          occasion: occasion,
          weather: weather,
        );
      } catch (_) {
        // HTTP fallback below
      }
    }
    return _sendViaHttp(
      mode: mode,
      message: message,
      history: history,
      orderNo: orderNo,
      occasion: occasion,
      weather: weather,
    );
  }

  static Future<Map<String, dynamic>> _sendViaHttp({
    required String mode,
    required String message,
    required List<Map<String, String>> history,
    String? orderNo,
    String? occasion,
    String? weather,
  }) {
    if (mode == 'stylist') {
      return ApiService.stylistChat(
        message: message,
        history: history,
        occasion: occasion,
        weather: weather,
      );
    }
    return ApiService.supportChat(
      message: message,
      history: history,
      orderNo: orderNo,
    );
  }

  static Future<Map<String, dynamic>> _sendViaWebSocket({
    required String mode,
    required String message,
    required List<Map<String, String>> history,
    String? orderNo,
    String? occasion,
    String? weather,
  }) async {
    final token = await ApiService.getToken();
    final uri = Uri.parse(webSocketUrl).replace(
      queryParameters: token != null && token.isNotEmpty
          ? {'token': token}
          : null,
    );

    final channel = WebSocketChannel.connect(uri);
    final completer = Completer<Map<String, dynamic>>();
    final requestId =
        '${DateTime.now().millisecondsSinceEpoch}-${message.hashCode}';
    late final StreamSubscription sub;

    sub = channel.stream.listen(
      (event) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(event as String) as Map<String, dynamic>;
        } catch (_) {
          return;
        }

        final type = data['type']?.toString();
        final incomingId = data['requestId']?.toString();

        if (type == 'ready' || type == 'ack' || type == 'pong') return;
        if (incomingId != null && incomingId != requestId) return;

        if (type == 'done' && data['success'] == true) {
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'reply': data['reply'],
              'suggestions': data['suggestions'],
            });
          }
          return;
        }

        if (type == 'error') {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(data['message']?.toString() ?? 'chat_error'),
            );
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('websocket_closed'));
        }
      },
    );

    channel.sink.add(
      jsonEncode({
        'type': 'chat',
        'mode': mode,
        'message': message,
        'history': history,
        'requestId': requestId,
        if (orderNo != null && orderNo.trim().isNotEmpty) 'orderNo': orderNo.trim(),
        if (occasion != null && occasion.trim().isNotEmpty)
          'occasion': occasion.trim(),
        if (weather != null && weather.trim().isNotEmpty) 'weather': weather.trim(),
      }),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: wsTimeoutSeconds),
        onTimeout: () => throw TimeoutException('chat_ws_timeout'),
      );
    } finally {
      await sub.cancel();
      await channel.sink.close();
    }
  }
}
