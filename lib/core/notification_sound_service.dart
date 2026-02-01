import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

/// Service to play notification sounds for SignalR messages
class NotificationSoundService extends GetxService {
  static NotificationSoundService get to => Get.find();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  /// Initialize the audio player
  Future<void> _initialize() async {
    try {
      // Set release mode to release the player after playing
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      _isInitialized = true;
      print('🔔 SAHAr Notification sound service initialized');
    } catch (e) {
      print('❌ SAHAr Error initializing sound service: $e');
    }
  }

  /// Play notification sound
  Future<void> playNotificationSound() async {
    if (!_isInitialized) {
      await _initialize();
    }

    try {
      // Play the notification sound from assets
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print('🔔 SAHAr Notification sound played');
    } catch (e) {
      print('❌ SAHAr Error playing notification sound: $e');
    }
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }
}
