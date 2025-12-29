import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/payment_service.dart';
import '../controllers/driver_onboarding_controller.dart';

class StripeOnboardingWebView extends StatefulWidget {
  final String url;
  final String accountId;
  final String driverId;

  const StripeOnboardingWebView({
    Key? key,
    required this.url,
    required this.accountId,
    required this.driverId,
  }) : super(key: key);

  @override
  State<StripeOnboardingWebView> createState() => _StripeOnboardingWebViewState();
}

class _StripeOnboardingWebViewState extends State<StripeOnboardingWebView> {
  late WebViewController _controller;
  RxDouble loadingProgress = 0.0.obs;
  RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('SAHAr: ========================================');
            print('SAHAr: 📄 Page Started: $url');
            print('SAHAr: ========================================');
            isLoading.value = true;
          },
          onPageFinished: (String url) {
            print('SAHAr: ========================================');
            print('SAHAr: ✅ Page Finished: $url');
            print('SAHAr: ========================================');
            isLoading.value = false;
            _checkIfOnboardingComplete(url);
          },
          onProgress: (int progress) {
            loadingProgress.value = progress / 100;
            print('SAHAr: Loading progress: $progress%');
          },
          onWebResourceError: (WebResourceError error) {
            print('SAHAr: ========================================');
            print('SAHAr: ❌ WebView Resource Error Detected');
            print('SAHAr: ========================================');
            print('SAHAr: Error Description: ${error.description}');
            print('SAHAr: Error Code: ${error.errorCode}');
            print('SAHAr: Error Type: ${error.errorType}');
            print('SAHAr: Failing URL: ${error.url}');
            print('SAHAr: Is For Main Frame: ${error.isForMainFrame}');
            print('SAHAr: ========================================');

            // Show user-friendly error for critical failures
            if (error.isForMainFrame == true) {
              Get.snackbar(
                'Connection Issue',
                'Having trouble loading the page. Please check your internet connection.',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: Duration(seconds: 3),
              );
            }
          },
          onHttpError: (HttpResponseError error) {
            print('SAHAr: ========================================');
            print('SAHAr: ❌ HTTP Error Detected');
            print('SAHAr: ========================================');
            print('SAHAr: Status Code: ${error.response?.statusCode}');
            print('SAHAr: URL: ${error.request?.uri}');
            print('SAHAr: ========================================');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('SAHAr: ========================================');
            print('SAHAr: 🔄 Navigation Request: ${request.url}');
            print('SAHAr: ========================================');

            // Detect completion - UPDATED URLs
            if (request.url.contains('home.pickurides.com/onboarding-complete.html') ||
                request.url.contains('stripe.com/setup/complete')) {
              print('SAHAr: 🎉 COMPLETION URL DETECTED!');
              _handleOnboardingComplete();
              return NavigationDecision.prevent;
            }

            // Detect link expiry - UPDATED URL
            if (request.url.contains('home.pickurides.com/onboarding-refresh.html')) {
              print('SAHAr: 🔄 REFRESH URL DETECTED - Link expired');
              _handleLinkExpired();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'StripeConsole',
        onMessageReceived: (JavaScriptMessage message) {
          print('SAHAr: 📱 JavaScript Message: ${message.message}');
        },
      )
      ..loadRequest(Uri.parse(widget.url));

    // Inject console logging script
    Future.delayed(Duration(seconds: 2), () {
      _injectConsoleLogger();
    });
  }

  void _injectConsoleLogger() {
    try {
      _controller.runJavaScript('''
        (function() {
          var originalLog = console.log;
          var originalError = console.error;
          var originalWarn = console.warn;
          
          console.log = function() {
            var message = Array.prototype.slice.call(arguments).join(' ');
            if (window.StripeConsole) {
              window.StripeConsole.postMessage('LOG: ' + message);
            }
            originalLog.apply(console, arguments);
          };
          
          console.error = function() {
            var message = Array.prototype.slice.call(arguments).join(' ');
            if (window.StripeConsole) {
              window.StripeConsole.postMessage('ERROR: ' + message);
            }
            originalError.apply(console, arguments);
          };
          
          console.warn = function() {
            var message = Array.prototype.slice.call(arguments).join(' ');
            if (window.StripeConsole) {
              window.StripeConsole.postMessage('WARN: ' + message);
            }
            originalWarn.apply(console, arguments);
          };
          
          // Capture unhandled errors
          window.addEventListener('error', function(e) {
            if (window.StripeConsole) {
              window.StripeConsole.postMessage('UNCAUGHT ERROR: ' + e.message + ' at ' + e.filename + ':' + e.lineno);
            }
          });
        })();
      ''');
      print('SAHAr: ✅ Console logger injected successfully');
    } catch (e) {
      print('SAHAr: ⚠️ Failed to inject console logger: $e');
    }
  }

  void _checkIfOnboardingComplete(String url) {
    if (url.contains('home.pickurides.com/onboarding-complete.html') ||
        url.contains('stripe.com/setup/complete') ||
        url.contains('connect.stripe.com/setup/complete')) {
      print('SAHAr: 🎯 Completion detected in page finish');
      _handleOnboardingComplete();
    }
  }

  Future<void> _handleOnboardingComplete() async {
    print('SAHAr: 🎉 Onboarding completed! Verifying...');

    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24),
            margin: EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.deepPurple),
                SizedBox(height: 20),
                Text(
                  'Verifying your account...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Wait for Stripe to process
    await Future.delayed(Duration(seconds: 3));

    final controller = Get.find<DriverOnboardingController>();
    bool isComplete = await controller.checkOnboardingStatus(widget.driverId);

    Get.back(); // Close loading dialog

    if (isComplete) {
      Get.back(); // Close WebView

      // Show success message
      Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Your payment account is now active!\n\nYou can start accepting ride payments.',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Get.back(); // Close dialog
                  // Navigate back to MainMap - it will check for Stripe account and show HomeScreen
                  Get.offAllNamed('/mainmap');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Get Started'),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    } else {
      Get.snackbar(
        'Almost There!',
        'Please complete all verification steps in the form',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    }
  }

  Future<void> _handleLinkExpired() async {
    print('SAHAr: ========================================');
    print('SAHAr: 🔄 Link expired, regenerating...');
    print('SAHAr: ========================================');

    Get.dialog(
      Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Refreshing link...'),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      String? newUrl = await PaymentService.createAccountLink(
        accountId: widget.accountId,
        refreshUrl: 'http://home.pickurides.com/onboarding-refresh.html',
        returnUrl: 'http://home.pickurides.com/onboarding-complete.html',
      );

      Get.back(); // Close loading

      if (newUrl != null) {
        print('SAHAr: ✅ New link generated, reloading WebView');
        _controller.loadRequest(Uri.parse(newUrl));
      } else {
        Get.back(); // Close WebView
        Get.snackbar('Error', 'Failed to refresh link. Please start over.');
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Failed to refresh link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Complete Payment Setup'),
          backgroundColor: MColor.primaryNavy,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: Column(
          children: [
            // Progress bar
            Obx(() => isLoading.value
                ? LinearProgressIndicator(
                    value: loadingProgress.value,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(MColor.primaryNavy),
                  )
                : SizedBox.shrink()),

            // Stripe's Built-in UI in WebView
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Text('Exit Setup?'),
        content: Text(
          'Your payment setup is not complete. You won\'t be able to receive payments until you finish.\n\nAre you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Close WebView
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Exit'),
          ),
        ],
      ),
    );
  }
}

