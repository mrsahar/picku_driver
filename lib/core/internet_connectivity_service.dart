import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Service to monitor internet connectivity status (WiFi/Cellular)
/// with stable connection detection (2-second delay to prevent false positives)
class InternetConnectivityService extends GetxService {
  static InternetConnectivityService get to => Get.find();

  // Observable variables
  var isConnected = true.obs;
  var connectionType = 'unknown'.obs; // wifi, cellular, none, ethernet, bluetooth
  var lastConnectionType = 'unknown';

  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Debounce timer for stable connection detection
  Timer? _debounceTimer;
  
  // Wait 2 seconds before confirming connection status change
  static const _stabilityDelay = Duration(seconds: 2);
  
  // Pending connection state (waiting for stability confirmation)
  bool? _pendingConnectionState;
  String? _pendingConnectionType;

  @override
  void onInit() {
    super.onInit();
    _initializeConnectivity();
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    try {
      // Get initial connectivity status
      final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result, immediate: true); // First check is immediate

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
        print('🌐 Connectivity changed: $result');
        _updateConnectionStatus(result);
      });

      print('✅ InternetConnectivityService initialized');
    } catch (e) {
      print('❌ Error initializing connectivity service: $e');
      // Assume connected if we can't check
      isConnected.value = true;
      connectionType.value = 'unknown';
    }
  }

  /// Update connection status with stability check (2-second delay)
  void _updateConnectionStatus(List<ConnectivityResult> results, {bool immediate = false}) {
    // Determine connection state from results
    bool hasConnection = false;
    String newConnectionType = 'none';

    // Check if any result indicates connection
    for (var result in results) {
      if (result == ConnectivityResult.wifi) {
        hasConnection = true;
        newConnectionType = 'wifi';
        break; // WiFi takes priority
      } else if (result == ConnectivityResult.mobile) {
        hasConnection = true;
        newConnectionType = 'cellular';
      } else if (result == ConnectivityResult.ethernet) {
        hasConnection = true;
        newConnectionType = 'ethernet';
      } else if (result == ConnectivityResult.bluetooth) {
        hasConnection = true;
        newConnectionType = 'bluetooth';
      }
    }

    // If no connection found in results, set to none
    if (!hasConnection) {
      newConnectionType = 'none';
    }

    print('🌐 Connection status: hasConnection=$hasConnection, type=$newConnectionType');

    // If immediate mode (first check or reconnection), update right away
    if (immediate) {
      _applyConnectionStatus(hasConnection, newConnectionType);
      return;
    }

    // Check if status actually changed
    if (hasConnection == isConnected.value && newConnectionType == connectionType.value) {
      print('🌐 Connection status unchanged, skipping');
      return;
    }

    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    // Store pending state
    _pendingConnectionState = hasConnection;
    _pendingConnectionType = newConnectionType;

    print('⏳ Connection change detected, waiting ${_stabilityDelay.inSeconds}s for stability...');
    print('⏳ Pending: hasConnection=$hasConnection, type=$newConnectionType');

    // Start 2-second stability timer
    _debounceTimer = Timer(_stabilityDelay, () {
      // After 2 seconds, if state hasn't changed again, apply it
      if (_pendingConnectionState != null && _pendingConnectionType != null) {
        print('✅ Connection stable for ${_stabilityDelay.inSeconds}s, applying change');
        _applyConnectionStatus(_pendingConnectionState!, _pendingConnectionType!);
        _pendingConnectionState = null;
        _pendingConnectionType = null;
      }
    });
  }

  /// Apply connection status change (after stability check)
  void _applyConnectionStatus(bool hasConnection, String type) {
    final wasConnected = isConnected.value;
    final previousType = connectionType.value;

    isConnected.value = hasConnection;
    connectionType.value = type;
    lastConnectionType = type;

    // Log status change
    if (wasConnected && !hasConnection) {
      print('🔴 Internet connection lost');
    } else if (!wasConnected && hasConnection) {
      print('🟢 Internet connection restored ($type)');
    } else if (previousType != type) {
      print('🔄 Connection type changed: $previousType → $type');
    }
  }

  /// Check if currently connected
  bool get hasConnection => isConnected.value;

  /// Check if connected via WiFi
  bool get isWiFi => connectionType.value == 'wifi';

  /// Check if connected via cellular/mobile data
  bool get isCellular => connectionType.value == 'cellular';

  /// Get current connection type as string
  String get currentConnectionType => connectionType.value;

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.onClose();
  }
}
