import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/message_screen_model.dart';
import 'package:pick_u_driver/core/unified_signalr_service.dart';

import '../core/chat_notification_service.dart';

class ChatController extends GetxController {
  // Use Unified SignalR Service
  final UnifiedSignalRService _signalRService = UnifiedSignalRService.to;
  final ChatNotificationService _notificationService = ChatNotificationService.to;

  // Observables
  final RxBool isLoading = false.obs;

  // Message input
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Ride and Driver info (received from route parameters)
  final RxString rideId = ''.obs;
  final RxString driverId = ''.obs;
  final RxString driverName = ''.obs;
  final RxString currentUserId = ''.obs;

  // Direct access to messages from UnifiedSignalRService - this is the key fix!
  RxList<ChatMessage> get messages => _signalRService.rideChatMessages;

  @override
  void onInit() {
    super.onInit();
    _initializeFromArguments();
    _initializeChat();
  }

  Future<void> _initializeFromArguments() async {
    // Get parameters passed from previous screen
    final args = Get.arguments as Map<String, dynamic>?;

    if (args != null) {
      rideId.value = args['rideId'] ?? '';
      driverId.value = args['driverId'] ?? '';
      driverName.value = args['driverName'] ?? 'Driver';
    }

    // Get user ID asynchronously
    SharedPrefsService.getUserId().then((userId) {
      currentUserId.value = userId ?? '';
      print(' SAHAr Current User ID loaded: ${currentUserId.value}');

      // Load chat history after user ID is loaded and connection is ready
      if (_signalRService.isConnected.value) {
        _loadChatHistory();
      }
    });

    print(' SAHAr ChatController initialized with:');
    print(' SAHAr Ride ID: ${rideId.value}');
    print(' SAHAr Driver ID: ${driverId.value}');
    print(' SAHAr Driver Name: ${driverName.value}');
  }

  Future<void> _initializeChat() async {
    try {
      isLoading.value = true;

      print('🔄 SAHAr Initializing chat...');
      print('🔄 SAHAr Using direct binding to UnifiedSignalRService messages');

      // Mark that user is on chat screen (no notifications while here)
      _notificationService.setOnChatScreen(true);

      // Request notification permission if not already requested
      if (!_notificationService.hasRequestedPermission.value) {
        final hasPermission = await _notificationService.checkNotificationPermission();
        if (!hasPermission) {
          // Show permission request dialog
          await _notificationService.showPermissionRequestDialog();
        }
      }

      // Ensure SignalR is connected
      if (!_signalRService.isConnected.value) {
        print('⚠️ SAHAr SignalR not connected, attempting to connect...');
        await _signalRService.connect();
      } else {
        print('✅ SAHAr SignalR already connected');
      }

      // Join ride chat and load history
      if (rideId.value.isNotEmpty) {
        print('💬 SAHAr Joining ride chat for: ${rideId.value}');
        await _signalRService.joinRideChat(rideId.value);
        await _loadChatHistory();
      } else {
        print('⚠️ SAHAr Cannot join chat - rideId is empty');
      }

      print('✅ SAHAr Chat initialization complete. Current messages: ${messages.length}');
    } catch (e) {
      print(' SAHAr ❌ Chat initialization error: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');
      Get.snackbar('Connection Error', 'Failed to initialize chat');
    } finally {
      isLoading.value = false;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadChatHistory() async {
    if (rideId.value.isEmpty) {
      print(' SAHAr Cannot load chat history - empty ride ID');
      return;
    }

    try {
      print(' SAHAr Loading chat history via UnifiedSignalR for ride: ${rideId.value}');
      await _signalRService.loadRideChatHistory(rideId.value);
    } catch (e) {
      print(' SAHAr Failed to request chat history: $e');
    }
  }

  Future<void> sendMessage() async {
    final messageText = messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    if (rideId.value.isEmpty || currentUserId.value.isEmpty) {
      Get.snackbar('Error', 'Missing ride or user information');
      return;
    }

    try {
      print(' SAHAr Sending message via UnifiedSignalR: $messageText');

      await _signalRService.sendRideChatMessage(
        rideId: rideId.value,
        senderId: currentUserId.value,
        message: messageText,
        senderRole: 'Driver',
      );

      messageController.clear();
      _scrollToBottom();

      print(' SAHAr Message sent successfully');
    } catch (e) {
      print(' SAHAr Failed to send message: $e');
      Get.snackbar('Send Error', 'Failed to send message');
    }
  }

  void retryConnection() async {
    if (!_signalRService.isConnected.value) {
      await _signalRService.connect();
      if (rideId.value.isNotEmpty) {
        await _signalRService.joinRideChat(rideId.value);
        await _loadChatHistory();
      }
    }
  }

  // Manual refresh method
  void refreshChatHistory() {
    if (_signalRService.isConnected.value) {
      _loadChatHistory();
    } else {
      Get.snackbar('Error', 'Not connected to chat service');
    }
  }

  // Computed properties for UI bindings
  RxBool get isConnected => _signalRService.isConnected;
  RxBool get isSending => _signalRService.isRideChatSending;
  RxBool get isLoadingMessages => _signalRService.isRideChatLoading;

  /// Update ride information when ChatScreen is already in stack
  void updateRideInfo({
    required String rideId,
    required String driverId,
    required String driverName,
  }) {
    print(' SAHAr Updating ride info - Ride: $rideId, Driver: $driverId, Name: $driverName');

    // Store the old ride ID to check if it changed
    String oldRideId = this.rideId.value;

    // Update the observable values
    this.rideId.value = rideId;
    this.driverId.value = driverId;
    this.driverName.value = driverName;

    // If the ride ID changed, we need to rejoin the chat room
    if (oldRideId != rideId && _signalRService.isConnected.value) {
      _signalRService.joinRideChat(rideId);
      _loadChatHistory();
    }
  }

  @override
  void onClose() {
    // Mark that user left chat screen (enable notifications again)
    _notificationService.setOnChatScreen(false);

    messageController.dispose();
    scrollController.dispose();
    _signalRService.clearRideChatMessages();
    super.onClose();
  }
}

// Extension for easy date formatting
extension DateTimeExtension on DateTime {
  String toTimeString() {
    final hour = this.hour > 12 ? this.hour - 12 : this.hour == 0 ? 12 : this.hour;
    final minute = this.minute.toString().padLeft(2, '0');
    final period = this.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String toDateTimeString() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays == 0) {
      return toTimeString();
    } else if (difference.inDays == 1) {
      return 'Yesterday ${toTimeString()}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${this.day}/${this.month}/${this.year}';
    }
  }
}

