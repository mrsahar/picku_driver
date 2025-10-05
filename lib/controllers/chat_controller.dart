import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/message_screen_model.dart';
import 'package:signalr_core/signalr_core.dart';
import 'dart:async';

class ChatController extends GetxController {
  // SignalR Connection
  HubConnection? hubConnection;
  Timer? _messagePollingTimer;

  // Observables
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isConnected = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxBool isLoadingMessages = false.obs;

  // Message input
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Ride and Driver info (received from route parameters)
  final RxString rideId = ''.obs;
  final RxString driverId = ''.obs;
  final RxString driverName = ''.obs;
  final RxString currentUserId = ''.obs;

  // Hub URL - adjust according to your backend
  final String hubUrl = "http://pickurides.com/ridechathub";

  @override
  void onInit() {
    super.onInit();
    _initializeFromArguments();
    _initializeSignalR();
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
      if (isConnected.value) {
        _loadChatHistory();
      }
    });

    print(' SAHAr ChatController initialized with:');
    print(' SAHAr Ride ID: ${rideId.value}');
    print(' SAHAr Driver ID: ${driverId.value}');
    print(' SAHAr Driver Name: ${driverName.value}');
  }

  Future<void> _initializeSignalR() async {
    try {
      isLoading.value = true;

      hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl)
          .build();

      // Listen for incoming messages
      hubConnection?.on('ReceiveMessage', (List<Object?>? arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final messageData = arguments[0] as Map<String, dynamic>;
          _handleReceivedMessage(messageData);
        }
      });

      // Listen for chat history
      hubConnection?.on('ReceiveRideChatHistory', (List<Object?>? arguments) {
        print(' SAHAr ReceiveRideChatHistory event triggered');
        if (arguments != null && arguments.isNotEmpty) {
          final historyData = arguments[0] as List<dynamic>;
          print(' SAHAr Chat history data received: ${historyData.length} messages');
          _handleChatHistory(historyData);
        }
      });

      // Handle connection events
      hubConnection?.onclose((error) {
        print(' SAHAr SignalR connection closed: $error');
        isConnected.value = false;
      });

      hubConnection?.onreconnecting((error) {
        print(' SAHAr SignalR reconnecting: $error');
        isConnected.value = false;
      });

      hubConnection?.onreconnected((connectionId) {
        print(' SAHAr SignalR reconnected: $connectionId');
        isConnected.value = true;
        _joinRideChat();
      });

      // Start connection
      await hubConnection?.start();
      isConnected.value = true;
      print(' SAHAr ✅ Connected to SignalR hub');

      // Join ride chat group
      await _joinRideChat();

      // Load chat history after connection is established
      if (currentUserId.value.isNotEmpty) {
        _loadChatHistory();
      }

    } catch (e) {
      print(' SAHAr ❌ SignalR connection error: $e');
      Get.snackbar('Connection Error', 'Failed to connect to chat service');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _joinRideChat() async {
    if (hubConnection != null && rideId.value.isNotEmpty) {
      try {
        await hubConnection?.invoke('JoinRideChat', args: [rideId.value]);
        print(' SAHAr 📌 Joined ride chat for: ${rideId.value}');
      } catch (e) {
        print(' SAHAr ❌ Failed to join ride chat: $e');
      }
    }
  }

  void _handleReceivedMessage(Map<String, dynamic> messageData) {
    try {
      print(' SAHAr Raw message data: $messageData');
      final chatMessage = ChatMessage.fromJson(messageData);
      final isFromCurrentUser = chatMessage.senderId == currentUserId.value;

      final messageWithUserFlag = chatMessage.copyWith(
        isFromCurrentUser: isFromCurrentUser,
      );

      messages.add(messageWithUserFlag);

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      print(' SAHAr 📨 Received message: ${chatMessage.message}');
    } catch (e) {
      print(' SAHAr ❌ Error handling received message: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    if (rideId.value.isEmpty) {
      print(' SAHAr Cannot load chat history - empty ride ID');
      return;
    }

    if (hubConnection == null || !isConnected.value) {
      print(' SAHAr Cannot load chat history - not connected to SignalR');
      return;
    }

    try {
      isLoadingMessages.value = true;
      print(' SAHAr Loading chat history via SignalR for ride: ${rideId.value}');

      // Request chat history via SignalR
      await hubConnection?.invoke('GetRideChatHistory', args: [rideId.value]);
      print(' SAHAr Chat history request sent successfully via SignalR');

    } catch (e) {
      print(' SAHAr Failed to request chat history: $e');
      isLoadingMessages.value = false;
    }
  }

  void _handleChatHistory(List<dynamic> chatHistory) {
    try {
      print(' SAHAr Processing chat history: ${chatHistory.length} messages');

      if (chatHistory.isEmpty) {
        print(' SAHAr No chat history found');
        messages.clear();
        isLoadingMessages.value = false;
        return;
      }

      List<ChatMessage> loadedMessages = [];

      for (var messageData in chatHistory) {
        try {
          print(' SAHAr Processing message: $messageData');
          final chatMessage = ChatMessage.fromJson(messageData);
          final isFromCurrentUser = chatMessage.senderId == currentUserId.value;

          loadedMessages.add(chatMessage.copyWith(isFromCurrentUser: isFromCurrentUser));
        } catch (e) {
          print(' SAHAr Error processing individual message: $e');
        }
      }

      messages.assignAll(loadedMessages);

      // Scroll to bottom after loading
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      print(' SAHAr Loaded ${loadedMessages.length} messages via SignalR');
    } catch (e) {
      print(' SAHAr Error handling chat history: $e');
    } finally {
      isLoadingMessages.value = false;
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

    if (hubConnection == null || !isConnected.value) {
      Get.snackbar('Error', 'Not connected to chat service');
      return;
    }

    try {
      isSending.value = true;

      print(' SAHAr Sending message via SignalR: $messageText');
      print(' SAHAr RideId: ${rideId.value}');
      print(' SAHAr SenderId: ${currentUserId.value}');

      // Send only via SignalR
      await hubConnection?.invoke('SendMessage', args: [
        rideId.value,
        currentUserId.value,
        messageText,
      ]);

      print(' SAHAr Message sent successfully via SignalR');

      // Clear input
      messageController.clear();

    } catch (e) {
      print(' SAHAr Failed to send message: $e');
      Get.snackbar('Send Error', 'Failed to send message via SignalR');
    } finally {
      isSending.value = false;
    }
  }

  void retryConnection() async {
    if (hubConnection?.state == HubConnectionState.disconnected) {
      await _initializeSignalR();
    }
  }

  // Manual refresh method
  void refreshChatHistory() {
    if (isConnected.value) {
      _loadChatHistory();
    } else {
      Get.snackbar('Error', 'Not connected to chat service');
    }
  }

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
    if (oldRideId != rideId && hubConnection != null && isConnected.value) {
      _joinRideChat();
      _loadChatHistory();
    }
  }

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    _messagePollingTimer?.cancel();
    hubConnection?.stop();
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