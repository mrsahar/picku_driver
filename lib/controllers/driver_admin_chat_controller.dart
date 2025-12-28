import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/unified_signalr_service.dart';
import '../core/sharePref.dart';
import '../models/chat_message_model.dart';

class DriverAdminChatController extends GetxController {
  // Use Unified SignalR Service
  final UnifiedSignalRService _signalRService = UnifiedSignalRService.to;

  // Observable variables
  final messages = <ChatMessage>[].obs;
  final isLoading = false.obs;
  final messageController = TextEditingController();
  final scrollController = ScrollController();

  // Driver info
  String? driverId;
  String? senderId;
  final senderRole = 'Driver';

  @override
  void onInit() {
    super.onInit();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      isLoading.value = true;

      // Get driver ID from SharedPreferences
      final driverData = await SharedPrefsService.getDriverID();
      driverId = driverData['userId'];
      senderId = driverData['userId'];

      if (driverId == null || driverId!.isEmpty) {
        Get.snackbar(
          'Error',
          'Driver ID not found. Please login again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
        return;
      }

      // Ensure SignalR is connected
      if (!_signalRService.isConnected.value) {
        await _signalRService.connect();
      }

      // Bind to unified service's admin chat messages
      ever(_signalRService.adminChatMessages, (msgs) {
        messages.value = msgs;
        _scrollToBottom();
      });

      // Join driver support and load history
      await _signalRService.joinDriverSupport();
      await _signalRService.loadDriverAdminChatHistory();

    } catch (e) {
      print('💥 Chat initialization error: $e');
      Get.snackbar(
        'Connection Error',
        'Failed to initialize chat',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendMessage() async {
    final messageText = messageController.text.trim();

    if (messageText.isEmpty) return;

    if (!_signalRService.isConnected.value) {
      Get.snackbar(
        'Not Connected',
        'Please wait for connection',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
      return;
    }

    try {
      await _signalRService.sendDriverAdminMessage(messageText);
      messageController.clear();
      print('📤 Message sent: $messageText');
    } catch (e) {
      print('Failed to send message: $e');
      Get.snackbar(
        'Send Failed',
        'Could not send message',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  Future<void> retryConnection() async {
    if (!_signalRService.isConnected.value) {
      await _signalRService.connect();
      if (driverId != null && driverId!.isNotEmpty) {
        await _signalRService.joinDriverSupport();
        await _signalRService.loadDriverAdminChatHistory();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Computed properties for UI bindings
  RxBool get isConnected => _signalRService.isConnected;
  RxBool get isSending => _signalRService.isAdminChatSending;

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    _signalRService.clearAdminChatMessages();
    super.onClose();
  }
}

