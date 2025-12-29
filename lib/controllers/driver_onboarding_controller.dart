import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../core/payment_service.dart';
import '../core/sharePref.dart';
import '../driver_screen/stripe_onboarding_webview.dart';

class DriverOnboardingController extends GetxController {
  final _apiProvider = Get.find<ApiProvider>();

  RxBool isLoading = false.obs;
  RxString stripeAccountId = ''.obs;
  RxBool onboardingComplete = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkExistingStripeAccount();
  }

  /// 📍 STEP 1: Start Stripe onboarding process
  Future<void> startStripeOnboarding() async {
    try {
      isLoading.value = true;

      print('SAHAr: ========================================');
      print('SAHAr: 🚀 STEP 1: Starting Stripe Onboarding');
      print('SAHAr: ========================================');

      // Check if there's an existing account
      String? existingAccountId = await SharedPrefsService.getDriverStripeAccountId();
      if (existingAccountId != null && existingAccountId.isNotEmpty) {
        print('SAHAr: ⚠️ Found old Stripe account: $existingAccountId');
        print('SAHAr: 🗑️ Clearing old account to create fresh US account...');
        await SharedPrefsService.clearDriverStripeAccountId();
        stripeAccountId.value = '';
      }

      // Get driver info from SharedPrefs
      String driverId = await SharedPrefsService.getUserId() ?? '';
      String email = await SharedPrefsService.getUserEmail() ?? '';
      String firstName = await SharedPrefsService.getUserFirstName() ?? '';
      String lastName = await SharedPrefsService.getUserLastName() ?? '';

      if (driverId.isEmpty || email.isEmpty) {
        Get.snackbar('Error', 'Driver information not found');
        print('SAHAr: ❌ Missing driver information');
        return;
      }

      print('SAHAr: Driver ID: $driverId');
      print('SAHAr: Email: $email');
      print('SAHAr: Name: $firstName $lastName');

      // 📍 STEP 2: Create NEW Stripe Connected Account (US)
      print('SAHAr: ----------------------------------------');
      print('SAHAr: 📝 STEP 2: Creating FRESH Stripe Account (US)');
      print('SAHAr: ----------------------------------------');

      final account = await PaymentService.createDriverConnectedAccount(
        email: email,
        firstName: firstName,
        lastName: lastName,
      );

      if (account == null) {
        print('SAHAr: ❌ Stripe account creation failed');
        Get.snackbar(
          'Setup Failed',
          'Unable to create your payment account. Please check:\n\n'
          '1. Your internet connection\n'
          '2. The email address is valid\n'
          '3. Try again in a few moments',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 6),
        );
        return;
      }

      String accountId = account['id'];
      String accountCountry = account['country'] ?? '';

      // NUCLEAR OPTION: If Stripe gave us wrong country, show error
      if (accountCountry != 'US') {
        print('SAHAr: ========================================');
        print('SAHAr: 🚨 CRITICAL: Stripe created ${accountCountry} account instead of US!');
        print('SAHAr: This means Stripe is restricting your account based on:');
        print('SAHAr: 1. Your email domain');
        print('SAHAr: 2. Your IP address location');
        print('SAHAr: 3. Stripe account restrictions');
        print('SAHAr: ========================================');

        Get.snackbar(
          'Country Restriction',
          'Stripe created a $accountCountry account instead of US.\n\n'
          'This happens when:\n'
          '• Your email/location suggests $accountCountry\n'
          '• Stripe restricts country selection\n\n'
          'You can still complete onboarding!\n'
          'Use a real phone number format for $accountCountry.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 8),
        );
      }

      stripeAccountId.value = accountId;

      print('SAHAr: ✅ Stripe account created');
      print('SAHAr: Account ID: $accountId');

      // 📍 STEP 3: Save to backend
      print('SAHAr: ----------------------------------------');
      print('SAHAr: 💾 STEP 3: Saving to Backend');
      print('SAHAr: ----------------------------------------');

      bool saved = await _updateStripeAccountInBackend(driverId, accountId);

      if (!saved) {
        print('SAHAr: ⚠️ Backend save failed, but continuing');
        Get.snackbar(
          'Warning',
          'Account created but failed to save. We\'ll retry after verification.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        print('SAHAr: ✅ Backend updated successfully');
      }

      // 📍 STEP 4: Get onboarding link
      print('SAHAr: ----------------------------------------');
      print('SAHAr: 🔗 STEP 4: Generating Onboarding Link');
      print('SAHAr: ----------------------------------------');

      String? onboardingUrl = await PaymentService.createAccountLink(
        accountId: accountId,
        refreshUrl: 'http://home.pickurides.com/onboarding-refresh.html',
        returnUrl: 'http://home.pickurides.com/onboarding-complete.html',
      );

      if (onboardingUrl == null) {
        Get.snackbar('Error', 'Failed to generate onboarding link');
        print('SAHAr: ❌ Failed to generate onboarding link');
        return;
      }

      print('SAHAr: ✅ Onboarding URL generated');
      print('SAHAr: URL: $onboardingUrl');

      // 📍 STEP 5: Open WebView
      print('SAHAr: ----------------------------------------');
      print('SAHAr: 📱 STEP 5: Opening WebView');
      print('SAHAr: ----------------------------------------');

      Get.to(() => StripeOnboardingWebView(
        url: onboardingUrl,
        accountId: accountId,
        driverId: driverId,
      ));

    } catch (e) {
      print('SAHAr: ❌ Exception in startStripeOnboarding: $e');
      Get.snackbar('Error', 'Failed to start onboarding: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Update Stripe Account ID in backend
  Future<bool> _updateStripeAccountInBackend(
    String driverId,
    String stripeAccountId,
  ) async {
    try {
      print('SAHAr: Calling: POST /api/Drivers/update-stripe-account-id');
      print('SAHAr: Payload: { driverId: $driverId, stripeAccountId: $stripeAccountId }');

      Response response = await _apiProvider.postData(
        '/api/Drivers/update-stripe-account-id',
        {
          'driverId': driverId,
          'stripeAccountId': stripeAccountId,
        },
      );

      print('SAHAr: Response Status: ${response.statusCode}');
      print('SAHAr: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('SAHAr: ✅ Backend updated successfully');
        return true;
      } else if (response.statusCode == 400) {
        print('SAHAr: ❌ Bad Request: ${response.body}');
        Get.snackbar('Error', response.body['message'] ?? 'Invalid data');
        return false;
      } else if (response.statusCode == 404) {
        print('SAHAr: ❌ Driver not found');
        Get.snackbar('Error', 'Driver not found in system');
        return false;
      } else {
        print('SAHAr: ❌ Unexpected status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('SAHAr: ❌ Exception in _updateStripeAccountInBackend: $e');
      return false;
    }
  }

  /// 📍 STEP 6: Check if onboarding is complete
  Future<bool> checkOnboardingStatus(String driverId) async {
    try {
      if (stripeAccountId.value.isEmpty) {
        print('SAHAr: ❌ No Stripe account ID available');
        return false;
      }

      print('SAHAr: ========================================');
      print('SAHAr: 🔍 STEP 6: Checking Onboarding Status');
      print('SAHAr: ========================================');
      print('SAHAr: Account ID: ${stripeAccountId.value}');

      // Get account details from Stripe
      final account = await PaymentService.getAccountDetails(stripeAccountId.value);

      if (account == null) {
        print('SAHAr: ❌ Failed to get account details');
        return false;
      }

      bool chargesEnabled = account['charges_enabled'] ?? false;
      bool payoutsEnabled = account['payouts_enabled'] ?? false;

      print('SAHAr: Charges enabled: $chargesEnabled');
      print('SAHAr: Payouts enabled: $payoutsEnabled');

      if (chargesEnabled && payoutsEnabled) {
        print('SAHAr: ========================================');
        print('SAHAr: ✅ ONBOARDING COMPLETE!');
        print('SAHAr: ========================================');

        // Update backend (retry in case it failed before)
        await _updateStripeAccountInBackend(driverId, stripeAccountId.value);

        onboardingComplete.value = true;

        // Save locally
        await SharedPrefsService.saveDriverStripeAccountId(stripeAccountId.value);

        return true;
      }

      print('SAHAr: ⚠️ Onboarding not complete yet');
      print('SAHAr: Driver needs to complete verification steps');
      return false;
    } catch (e) {
      print('SAHAr: ❌ Exception in checkOnboardingStatus: $e');
      return false;
    }
  }

  /// Check existing Stripe account on app start
  Future<void> checkExistingStripeAccount() async {
    try {
      String? savedAccountId = await SharedPrefsService.getDriverStripeAccountId();

      if (savedAccountId != null && savedAccountId.isNotEmpty) {
        print('SAHAr: ========================================');
        print('SAHAr: Found existing Stripe account: $savedAccountId');
        print('SAHAr: Will verify account status...');
        print('SAHAr: ========================================');

        stripeAccountId.value = savedAccountId;

        // Verify it's still active and complete
        String driverId = await SharedPrefsService.getUserId() ?? '';
        bool isComplete = await checkOnboardingStatus(driverId);

        if (!isComplete) {
          print('SAHAr: ⚠️ Existing account is not complete');
          print('SAHAr: Driver will need to complete or restart onboarding');
        }
      } else {
        print('SAHAr: ========================================');
        print('SAHAr: No existing Stripe account found');
        print('SAHAr: Driver needs to complete payment setup');
        print('SAHAr: ========================================');
      }
    } catch (e) {
      print('SAHAr: Error checking existing account: $e');
    }
  }
}
