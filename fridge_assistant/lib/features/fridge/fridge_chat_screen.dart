import 'dart:async';
import 'package:fridge_assistant/core/localization/app_material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_message_model.dart';
import '../../models/fridge_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';

class FridgeChatScreen extends StatefulWidget {
  final FridgeModel fridge;

  const FridgeChatScreen({super.key, required this.fridge});

  @override
  State<FridgeChatScreen> createState() => _FridgeChatScreenState();
}

class _FridgeChatScreenState extends State<FridgeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final List<ChatMessageModel> _messages = [];
  final Set<int> _typingUsers = {};
  int? _currentUserId;
  bool _isLoading = true;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _stoppedTypingSubscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _chatService.activeChatFridgeId = widget.fridge.fridgeId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await AuthService().getUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?['user_id'];
      });
    }

    // Load history
    final history = await _chatService.getHistory(widget.fridge.fridgeId);
    if (mounted) {
      setState(() {
        _messages.addAll(history);
        _isLoading = false;
      });
      _scrollToBottom();

      // Clear badge
      if (history.isNotEmpty) {
        _chatService.markAsRead(widget.fridge.fridgeId, history.last.messageId);
      }
    }

    // Init SignalR
    await _chatService.init(widget.fridge.fridgeId);

    // Listen for new messages
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (mounted && message.fridgeId == widget.fridge.fridgeId) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();

        // Mark as read immediately since we are in the chat
        _chatService.markAsRead(widget.fridge.fridgeId, message.messageId);
      }
    });

    // Listen for typing events
    _typingSubscription = _chatService.typingStream.listen((data) {
      if (mounted) {
        final userId = data['user_id'] as int;
        if (userId != _currentUserId) {
          setState(() {
            _typingUsers.add(userId);
          });
        }
      }
    });

    // Listen for stopped typing events
    _stoppedTypingSubscription = _chatService.stoppedTypingStream.listen((
      userId,
    ) {
      if (mounted) {
        setState(() {
          _typingUsers.remove(userId);
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _chatService.activeChatFridgeId = null;
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _stoppedTypingSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();

    // Stop typing when leaving
    if (_typingUsers.isNotEmpty) {
      _chatService.stopTyping(widget.fridge.fridgeId);
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _typingTimer?.cancel();
    await _chatService.stopTyping(widget.fridge.fridgeId);
    setState(() {
      _typingUsers.clear();
    });
    await _chatService.sendMessage(widget.fridge.fridgeId, content);
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      // Send typing indicator
      _chatService.sendTyping(widget.fridge.fridgeId);

      // Reset timer
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.stopTyping(widget.fridge.fridgeId);
      });
    }
  }

  void _showMessageOptions(BuildContext context, ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Chỉnh sửa'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(ChatMessageModel message) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa tin nhắn'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 1,
          decoration: InputDecoration(
            hintText: context.tr('Nội dung tin nhắn...'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;

              final success = await _chatService.editMessage(
                message.messageId,
                newContent,
              );
              if (success && mounted) {
                // Update locally
                final index = _messages.indexOf(message);
                if (index >= 0) {
                  _messages[index] = ChatMessageModel(
                    messageId: message.messageId,
                    fridgeId: message.fridgeId,
                    userId: message.userId,
                    displayName: message.displayName,
                    photoUrl: message.photoUrl,
                    content: newContent,
                    status: message.status,
                    createdAt: message.createdAt,
                  );
                  setState(() {});
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(ChatMessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tin nhắn?'),
        content: const Text('Bạn có chắc chắn muốn xóa tin nhắn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final success = await _chatService.deleteMessage(
                message.messageId,
              );
              if (success && mounted) {
                _messages.removeWhere((m) => m.messageId == message.messageId);
                setState(() {});
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fridge.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Trò chuyện nhóm',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có tin nhắn nào.\nHãy bắt đầu cuộc trò chuyện!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.userId == _currentUserId;
                      return GestureDetector(
                        onLongPress: isMe
                            ? () => _showMessageOptions(context, message)
                            : null,
                        child: _buildMessageBubble(message, isMe),
                      );
                    },
                  ),
          ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _typingUsers.length == 1
                    ? 'Đang có 1 người gõ...'
                    : 'Đang có ${_typingUsers.length} người gõ...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(message.photoUrl, message.displayName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        if (message.status == 'pending')
                          const Icon(
                            Icons.schedule,
                            size: 10,
                            color: Colors.grey,
                          )
                        else if (message.status == 'delivered')
                          const Icon(
                            Icons.done_all,
                            size: 10,
                            color: Colors.cyan,
                          )
                        else
                          const Icon(Icons.done, size: 10, color: Colors.grey),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String name) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey[200],
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            )
          : null,
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: context.tr('Nhập tin nhắn...'),
                  border: InputBorder.none,
                  hintStyle: const TextStyle(fontSize: 13),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: _onTextChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
