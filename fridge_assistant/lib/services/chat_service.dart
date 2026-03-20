import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'local_notification_service.dart';
import 'auth_service.dart';
import 'fridge_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  HubConnection? _hubConnection;
  int? activeChatFridgeId;
  int? _currentUserId;
  final Set<int> _joinedFridgeIds = {};
  
  final _messageController = StreamController<ChatMessageModel>.broadcast();
  final _unreadUpdateController = StreamController<void>.broadcast();
  
  Stream<ChatMessageModel> get messageStream => _messageController.stream;
  Stream<void> get unreadUpdateStream => _unreadUpdateController.stream;

  static const String _lastSeenKeyPrefix = 'chat_last_seen_';

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  Future<void> initGlobal() async {
    final user = await AuthService().getUser();
    _currentUserId = user?['user_id'];
    
    final baseUrl = ApiService.baseUrl;
    final token = await _getToken();
    if (token == null) return;

    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: () async => token,
    );

    _hubConnection = HubConnectionBuilder()
        .withUrl('$baseUrl/chatHub', options: httpOptions)
        .withAutomaticReconnect()
        .build();

    _hubConnection!.onreconnected(({connectionId}) async {
      debugPrint('SignalR reconnected: $connectionId. Re-joining groups...');
      for (var fridgeId in _joinedFridgeIds.toList()) {
        await joinFridgeGroup(fridgeId);
      }
    });

    _hubConnection!.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = Map<String, dynamic>.from(arguments[0] as Map);
        final message = ChatMessageModel.fromJson(data);
        
        // Cập nhật stream cho màn hình chat hiện tại
        _messageController.add(message);
        
        // Cập nhật chấm đỏ thông báo
        _unreadUpdateController.add(null);

        // Hiển thị thông báo Local nếu:
        // 1. Tin nhắn không phải của mình
        // 2. Mình đang không ở trong màn hình chat của tủ lạnh đó
        if (message.userId != _currentUserId && message.fridgeId != activeChatFridgeId) {
          LocalNotificationService.showChatNotification(
            senderName: message.displayName,
            content: message.content,
            fridgeId: message.fridgeId,
          );
        }
      }
    });

    try {
      await _hubConnection!.start();
      debugPrint('SignalR Global connected');
      
      // Tham gia tất cả các nhóm tủ lạnh mà người dùng thuộc về
      final fridges = await FridgeService().getFridges();
      for (var f in fridges) {
        await joinFridgeGroup(f.fridgeId);
      }
    } catch (e) {
      debugPrint('SignalR initGlobal error: $e');
    }
  }

  Future<void> joinFridgeGroup(int fridgeId) async {
    if (!isConnected || _joinedFridgeIds.contains(fridgeId)) return;
    try {
      await _hubConnection!.invoke('JoinFridgeGroup', args: [fridgeId]);
      _joinedFridgeIds.add(fridgeId);
      debugPrint('Joined fridge group: $fridgeId');
    } catch (e) {
      debugPrint('Error joining fridge group $fridgeId: $e');
    }
  }

  Future<void> init(int fridgeId) async {
    if (!isConnected) {
      await initGlobal();
    } else {
      await joinFridgeGroup(fridgeId);
    }
  }

  Future<void> sendMessage(int fridgeId, String content) async {
    if (_hubConnection == null || !isConnected) {
      debugPrint('SignalR not connected, trying to reconnect...');
      await init(fridgeId);
      if (!isConnected) return;
    }

    try {
      await _hubConnection!.invoke('SendMessage', args: [fridgeId, content]);
    } catch (e) {
      debugPrint('SignalR sendMessage error: $e');
    }
  }

  Future<List<ChatMessageModel>> getHistory(int fridgeId) async {
    try {
      final resp = await ApiService.get('/api/v1/chat/$fridgeId', withAuth: true);
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('ChatService.getHistory error: $e');
    }
    return [];
  }

  Future<void> stop() async {
    try {
      if (_hubConnection != null) {
        await _hubConnection!.stop();
      }
    } catch (e) {
      debugPrint('SignalR stop error: $e');
    }
    _hubConnection = null;
  }

  Future<void> markAsRead(int fridgeId, int? latestMessageId) async {
    if (latestMessageId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_lastSeenKeyPrefix$fridgeId', latestMessageId);
    _unreadUpdateController.add(null);
  }

  Future<Map<int, bool>> getUnreadStatuses(List<int> fridgeIds) async {
    if (fridgeIds.isEmpty) return {};
    try {
      final idsParam = fridgeIds.join(',');
      final resp = await ApiService.get('/api/v1/chat/latest?fridgeIds=$idsParam', withAuth: true);
      
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        final prefs = await SharedPreferences.getInstance();
        final Map<int, bool> unreadMap = {};

        for (var item in list) {
          final fid = item['fridge_id'] as int;
          final latestId = item['latest_message_id'] as int;
          final lastSeen = prefs.getInt('$_lastSeenKeyPrefix$fid') ?? 0;
          unreadMap[fid] = latestId > lastSeen;
        }
        return unreadMap;
      }
    } catch (e) {
      debugPrint('ChatService.getUnreadStatuses error: $e');
    }
    return {};
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
