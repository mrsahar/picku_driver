import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

/// Service to play notification sounds for SignalR messages
class NotificationSoundService extends GetxService {
  static NotificationSoundService get to => Get.find();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  /// Initialize the audio player
  Future<void> _initialize() async {
    try {
      _audioPlayer = AudioPlayer();
      // Set release mode to release the player after playing
      await _audioPlayer!.setReleaseMode(ReleaseMode.release);
      _isInitialized = true;
      print('🔔 SAHAr Notification sound service initialized');
    } catch (e) {
      print('❌ SAHAr Error initializing sound service: $e');
      _isInitialized = false;
    }
  }

  /// Play notification sound for chat messages
  Future<void> playNotificationSound() async {
    if (!_isInitialized || _audioPlayer == null) {
      await _initialize();
    }

    if (_audioPlayer == null) {
      print('⚠️ SAHAr Audio player not available, skipping sound');
      return;
    }

    try {
      // Stop any currently playing sound first
      await _audioPlayer!.stop();
      // Play the notification sound from assets
      await _audioPlayer!.play(AssetSource('sounds/notification.mp3'));
      print('🔔 SAHAr Notification sound played');
    } catch (e) {
      print('❌ SAHAr Error playing notification sound: $e');
    }
  }

  @override
  void onClose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    super.onClose();
  }
}
