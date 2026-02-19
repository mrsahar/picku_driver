// sharePref.dart
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _keyUserToken = 'user_token';
  static const String _keyTokenExpires = 'token_expires';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserFullName = 'user_full_name';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyStripeAccountId = 'driver_stripe_account_id';
  static const String _keyRideStatus = 'ride_status';
  static const String _keyApprovalStatus = 'approval_status';

  // Save user login data
  static Future<void> saveUserData({
    required String token,
    required String expires,
    required String userId,
    required String email,
    required String fullName,
    String? rideStatus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_keyUserToken, token);
      await prefs.setString(_keyTokenExpires, expires);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyUserEmail, email);
      await prefs.setString(_keyUserFullName, fullName);
      await prefs.setBool(_keyIsLoggedIn, true);

      if (rideStatus != null) {
        await prefs.setString(_keyRideStatus, rideStatus);
      }

      print(' SAHAr 💾 All user data saved to SharedPreferences successfully');
    } catch (e) {
      print(' SAHAr 💥 Error saving to SharedPreferences: $e');
    }
  }

  // Save user login data from API response
  static Future<void> saveUserDataFromResponse(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (data['token'] != null) {
        await prefs.setString(_keyUserToken, data['token']);
      }

      if (data['expires'] != null) {
        await prefs.setString(_keyTokenExpires, data['expires']);
      }

      if (data['userId'] != null) {
        await prefs.setString(_keyUserId, data['userId']);
      }

      if (data['email'] != null) {
        await prefs.setString(_keyUserEmail, data['email']);
      }

      if (data['fullName'] != null) {
        await prefs.setString(_keyUserFullName, data['fullName']);
      }

      if (data['stripeAccountId'] != null) {
        await prefs.setString(_keyStripeAccountId, data['stripeAccountId']);
        print(' SAHAr 💾 Stripe Account ID saved: ${data['stripeAccountId']}');
      }

      if (data['approvalStatus'] != null) {
        await prefs.setString(_keyApprovalStatus, data['approvalStatus']);
        print(' SAHAr 💾 Approval Status saved: ${data['approvalStatus']}');
      }

      if (data['rideStatus'] != null) {
        await prefs.setString(_keyRideStatus, data['rideStatus']);
        print(' SAHAr 💾 Ride Status saved: ${data['rideStatus']}');
      }

      await prefs.setBool(_keyIsLoggedIn, true);
      print(' SAHAr 💾 User data saved from API response');
    } catch (e) {
      print(' SAHAr 💥 Error saving API response to SharedPreferences: $e');
    }
  }

  // Get user token
  static Future<String?> getUserToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserToken);
    } catch (e) {
      print(' SAHAr 💥 Error getting token: $e');
      return null;
    }
  }

  // Get token expiry
  static Future<String?> getTokenExpires() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyTokenExpires);
    } catch (e) {
      print(' SAHAr 💥 Error getting token expiry: $e');
      return null;
    }
  }

  // Get user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);
      print(' SAHAr 📱 Retrieved user ID: $userId'); // Debug log
      return userId;
    } catch (e) {
      print(' SAHAr 💥 Error getting user ID: $e');
      return null;
    }
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (e) {
      print(' SAHAr 💥 Error getting user email: $e');
      return null;
    }
  }

  // Get user full name
  static Future<String?> getUserFullName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserFullName);
    } catch (e) {
      print(' SAHAr 💥 Error getting user full name: $e');
      return null;
    }
  }

  // Get ride status
  static Future<String?> getRideStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRideStatus);
    } catch (e) {
      print(' SAHAr 💥 Error getting ride status: $e');
      return null;
    }
  }

  // Get user first name
  static Future<String?> getUserFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullName = prefs.getString(_keyUserFullName);
      if (fullName == null || fullName.isEmpty) return '';

      // Split full name and return first part
      final nameParts = fullName.split(' ');
      return nameParts.isNotEmpty ? nameParts.first : '';
    } catch (e) {
      print(' SAHAr 💥 Error getting user first name: $e');
      return null;
    }
  }

  // Get user last name
  static Future<String?> getUserLastName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullName = prefs.getString(_keyUserFullName);
      if (fullName == null || fullName.isEmpty) return '';

      // Split full name and return last part(s)
      final nameParts = fullName.split(' ');
      if (nameParts.length > 1) {
        return nameParts.sublist(1).join(' ');
      }
      return '';
    } catch (e) {
      print(' SAHAr 💥 Error getting user last name: $e');
      return null;
    }
  }

  // Get all user data
  static Future<Map<String, String?>> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'token': prefs.getString(_keyUserToken),
        'expires': prefs.getString(_keyTokenExpires),
        'userId': prefs.getString(_keyUserId),
        'email': prefs.getString(_keyUserEmail),
        'fullName': prefs.getString(_keyUserFullName),
        'stripeAccountId': prefs.getString(_keyStripeAccountId),
        'approvalStatus': prefs.getString(_keyApprovalStatus),
        'rideStatus': prefs.getString(_keyRideStatus),
        'isLoggedIn': prefs.getBool(_keyIsLoggedIn)?.toString(),
      };
    } catch (e) {
      print(' SAHAr 💥 Error retrieving user data: $e');
      return {};
    }
  }
  // Get all user data
  static Future<Map<String, String?>> getDriverID() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'userId': prefs.getString(_keyUserId),
      };
    } catch (e) {
      print(' SAHAr 💥 Error retrieving user data: $e');
      return {};
    }
  }

  // Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      print(' SAHAr 💥 Error checking login status: $e');
      return false;
    }
  }

  // Check if token is expired
  static Future<bool> isTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiresStr = prefs.getString(_keyTokenExpires);

      if (expiresStr == null) return true;

      final expiryDate = DateTime.parse(expiresStr);
      final now = DateTime.now();

      return now.isAfter(expiryDate);
    } catch (e) {
      print(' SAHAr 💥 Error checking token expiry: $e');
      return true; // Assume expired if there's an error
    }
  }

  // Save driver's Stripe account ID
  static Future<void> saveDriverStripeAccountId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStripeAccountId, accountId);
    print(' SAHAr 💾 Stripe Account ID saved: $accountId');
  }

  // Get driver's Stripe account ID
  static Future<String?> getDriverStripeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getString(_keyStripeAccountId);
    if (accountId != null) {
      print(' SAHAr 📱 Retrieved Stripe Account ID: $accountId');
    }
    return accountId;
  }

  // Clear driver's Stripe account ID (for testing or retry)
  static Future<void> clearDriverStripeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStripeAccountId);
    print(' SAHAr 🗑️ Stripe Account ID cleared - ready for fresh onboarding');
  }

  // Update ride status only
  static Future<void> updateRideStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRideStatus, status);
      print(' SAHAr 💾 Ride Status updated: $status');
    } catch (e) {
      print(' SAHAr 💥 Error updating ride status: $e');
    }
  }

  // Clear all user data (for logout)
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyUserToken);
      await prefs.remove(_keyTokenExpires);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserFullName);
      await prefs.remove(_keyStripeAccountId);
      await prefs.remove(_keyApprovalStatus);
      await prefs.remove(_keyRideStatus);
      await prefs.setBool(_keyIsLoggedIn, false);

      print(' SAHAr 💾 User data cleared from SharedPreferences');
    } catch (e) {
      print(' SAHAr 💥 Error clearing SharedPreferences: $e');
    }
  }
}