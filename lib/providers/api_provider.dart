import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/models/forgot_password_model.dart';
import 'package:pick_u_driver/models/login_model.dart';
import 'package:pick_u_driver/models/otp_model.dart';
import 'package:pick_u_driver/models/reset_password_model.dart';
import 'package:pick_u_driver/models/signup_model.dart';

class ApiProvider extends GetConnect {
  final GlobalVariables _globalVars = GlobalVariables.instance;

  @override
  void onInit() {
    super.onInit();

    // Configure base URL
    httpClient.baseUrl = _globalVars.baseUrl;

    // Add request interceptor
    httpClient.addRequestModifier<dynamic>((request) {
      request.headers['Content-Type'] = 'application/json';
      if (_globalVars.userToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${_globalVars.userToken}';
      }
      return request;
    });

    // Add response interceptor
    httpClient.addResponseModifier<dynamic>((request, response) {
      print(' SAHAr API Response: ${response.statusCode} - ${response.bodyString}');
      return response;
    });
  }

  // GET Request
  Future<Response> getData(String endpoint) async {
    try {
      _globalVars.setLoading(true);
      final response = await get(endpoint);
      _globalVars.setLoading(false);
      return response;
    } catch (e) {
      _globalVars.setLoading(false);
      return Response(
        statusCode: 500,
        statusText: 'Network Error: $e',
      );
    }
  }

  // POST Request
  Future<Response> postData(String endpoint, Map<String, dynamic> data) async {
    try {
      _globalVars.setLoading(true);
      final response = await post(endpoint, data);
      _globalVars.setLoading(false);
      return response;
    } catch (e) {
      _globalVars.setLoading(false);
      return Response(
        statusCode: 500,
        statusText: 'Network Error: $e',
      );
    }
  }
  // POST Request - handles both JSON and FormData
  Future<Response> postData2(String endpoint, dynamic data) async {
    try {
      _globalVars.setLoading(true);
      print(' SAHAr : POST $endpoint');

      Response response;
      if (data is FormData) {
        // For FormData, don't use the interceptor - send directly
        final headers = <String, String>{};
        if (_globalVars.userToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${_globalVars.userToken}';
        }
        // Don't set Content-Type - let it be set automatically for multipart

        response = await httpClient.post(
          endpoint,
          body: data,
          headers: headers,
        );
      } else {
        // Use regular post for JSON data
        response = await post(endpoint, data);
      }

      print(' SAHAr : POST Response = ${response.bodyString}');
      _globalVars.setLoading(false);
      return response;
    } catch (e) {
      _globalVars.setLoading(false);
      print(' SAHAr : Exception during POST request: $e');
      return Response(
        statusCode: 500,
        statusText: 'Network Error: $e',
      );
    }
  }

  Future<Response> uploadMultipart(String endpoint, Map<String, dynamic> fileData) async {
    try {
      _globalVars.setLoading(true);

      final uri = Uri.parse('${_globalVars.baseUrl}$endpoint');
      print(' SAHAr : Upload URI: $uri');

      var request = http.MultipartRequest('POST', uri);

      // Add authorization header if token exists
      if (_globalVars.userToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${_globalVars.userToken}';
      }

      print(' SAHAr : Request headers: ${request.headers}');

      // Add DriverId field
      request.fields['DriverId'] = fileData['driverId'];
      print(' SAHAr : Added field: DriverId = ${fileData['driverId']}');

      // Add files from the map
      final files = fileData['files'] as Map<String, dynamic>;
      for (var entry in files.entries) {
        final fileInfo = entry.value as Map<String, dynamic>;
        final bytes = fileInfo['bytes'] as List<int>;
        final filename = fileInfo['filename'] as String;
        final contentType = fileInfo['contentType'] as String;

        request.files.add(http.MultipartFile.fromBytes(
          entry.key,
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ));

        print(' SAHAr : Added file: ${entry.key} - $filename (${bytes.length} bytes, $contentType)');
      }

      print(' SAHAr : Sending multipart request with ${request.files.length} files...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(' SAHAr : Response status: ${response.statusCode}');
      print(' SAHAr : Response headers: ${response.headers}');
      print(' SAHAr : Response body: ${response.body}');

      _globalVars.setLoading(false);

      // Parse response body - handle both JSON and plain text
      dynamic responseBody;
      try {
        if (response.body.isNotEmpty) {
          // Try to parse as JSON first
          responseBody = jsonDecode(response.body);
        } else {
          responseBody = '';
        }
      } catch (e) {
        // If JSON parsing fails, it's plain text - wrap it in a Map for consistency
        print(' SAHAr : Response is plain text, wrapping in map');
        responseBody = {
          'message': response.body,
          'success': response.statusCode == 200,
        };
      }

      return Response(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase,
        body: responseBody,
      );
    } catch (e, stackTrace) {
      _globalVars.setLoading(false);
      print(' SAHAr : Exception during upload: $e');
      print(' SAHAr : Stack trace: $stackTrace');
      return Response(
        statusCode: 500,
        statusText: 'Upload Error: $e',
      );
    }
  }

  // PUT Request
  Future<Response> putData(String endpoint, Map<String, String> data) async {
    try {
      _globalVars.setLoading(true);
      final response = await put(endpoint, data);
      _globalVars.setLoading(false);
      return response;
    } catch (e) {
      _globalVars.setLoading(false);
      return Response(
        statusCode: 500,
        statusText: 'Network Error: $e',
      );
    }
  }

  // DELETE Request
  Future<Response> deleteData(String endpoint) async {
    try {
      _globalVars.setLoading(true);
      final response = await delete(endpoint);
      _globalVars.setLoading(false);
      return response;
    } catch (e) {
      _globalVars.setLoading(false);
      return Response(
        statusCode: 500,
        statusText: 'Network Error: $e',
      );
    }
  }

  // User Authentication APIs - SignUp, Login, OTP Verification, Forgot Password, Reset Password
  Future<SignUpResponse> signUp(SignUpRequest request) async {
    try {
      print(' SAHAr 🚀 MRSAHAr ApiProvider: Starting signUp request');
      print(' SAHAr 📦 MRSAHAr ApiProvider: Request data: ${request.toJson()}');

      final response = await postData('/api/Drivers/register', request.toJson());

      print(' SAHAr 📨 MRSAHAr ApiProvider: Response received');
      print(' SAHAr 📊 MRSAHAr ApiProvider: Status Code: ${response.statusCode}');
      print(' SAHAr 📄 MRSAHAr ApiProvider: Response Body: ${response.body}');
      print(' SAHAr 📝 MRSAHAr ApiProvider: Response Type: ${response.body.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ MRSAHAr ApiProvider: Success status code');

        String message = 'Registration successful';
        dynamic data = response.body;

        // Handle different response body types
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            // JSON response
            final Map<String, dynamic> bodyMap = response.body;
            message = bodyMap['message']?.toString() ?? message;
            print(' SAHAr 📝 MRSAHAr ApiProvider: Extracted message from Map: $message');
          } else if (response.body is String) {
            // String response
            message = response.body;
            print(' SAHAr 📝 MRSAHAr ApiProvider: Using String response: $message');
          } else if (response.body is List) {
            // Array response
            message = 'Registration successful';
            print(' SAHAr 📝 MRSAHAr ApiProvider: Array response received');
          } else {
            // Other types
            message = 'Registration successful';
            print(' SAHAr 📝 MRSAHAr ApiProvider: Unknown response type: ${response.body.runtimeType}');
          }
        }

        return SignUpResponse(
          success: true,
          message: message,
          data: data,
        );

      } else {
        print(' SAHAr ❌ MRSAHAr ApiProvider: Error status code: ${response.statusCode}');

        String errorMessage = 'Registration failed';

        // Handle error response body
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            final Map<String, dynamic> bodyMap = response.body;
            errorMessage = bodyMap['message']?.toString() ??
                bodyMap['error']?.toString() ??
                errorMessage;
          } else if (response.body is String) {
            errorMessage = response.body;
          } else {
            errorMessage = 'Registration failed with status: ${response.statusCode}';
          }
        }

        print(' SAHAr 📝 MRSAHAr ApiProvider: Error message: $errorMessage');

        return SignUpResponse(
          success: false,
          message: errorMessage,
        );
      }

    } catch (e, stackTrace) {
      print(' SAHAr 💥 MRSAHAr ApiProvider: Exception in signUp: $e');
      print(' SAHAr 📍 MRSAHAr ApiProvider: Stack trace: $stackTrace');

      String errorMessage = 'Network error. Please check your connection.';

      // Handle specific error types
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timeout. Please try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Connection failed. Please check your internet.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response from server.';
      } else if (e.toString().contains('type \'Null\'')) {
        errorMessage = 'Invalid response format from server.';
      }

      return SignUpResponse(
        success: false,
        message: errorMessage,
      );
    }
  }

  Future<OTPResponse> verifyOTP(OTPRequest request) async {
    try {
      print(' SAHAr 🚀 MRSAHAr ApiProvider: Starting OTP verification for: ${_globalVars.baseUrl}/api/Drivers/verify');
      print(' SAHAr 📦 MRSAHAr ApiProvider: OTP Request data: ${request.toJson()}');

      final response = await postData('/api/Drivers/verify', request.toJson());

      print(' SAHAr 📋 MRSAHAr ApiProvider: OTP response received');
      print(' SAHAr 📊 MRSAHAr ApiProvider: Response status code: ${response.statusCode}');
      print(' SAHAr 📄 MRSAHAr ApiProvider: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ MRSAHAr ApiProvider: OTP verification successful');

        String message = 'OTP verified successfully';
        dynamic data = response.body;

        if (response.body != null && response.body is Map<String, dynamic>) {
          message = response.body['message'] ?? message;
        }

        return OTPResponse(
          success: true,
          message: message,
          data: data,
        );
      } else {
        print(' SAHAr ❌ MRSAHAr ApiProvider: OTP verification failed with status: ${response.statusCode}');

        String errorMessage = 'OTP verification failed';
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            errorMessage = response.body['message'] ?? errorMessage;
          } else if (response.body is String) {
            errorMessage = response.body;
          }
        }

        return OTPResponse(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      print(' SAHAr 💥 MRSAHAr ApiProvider: OTP verification exception: $e');
      print(' SAHAr 📍 MRSAHAr ApiProvider: Stack trace: $stackTrace');

      return OTPResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      print(' SAHAr 🚀 MRSAHAr ApiProvider: Starting login for: ${_globalVars.baseUrl}/api/Drivers/login');
      print(' SAHAr 📦 MRSAHAr ApiProvider: Login Request data: ${request.toJson()}');

      final response = await postData('/api/Drivers/login', request.toJson());

      print(' SAHAr 📋 MRSAHAr ApiProvider: Login response received');
      print(' SAHAr 📊 MRSAHAr ApiProvider: Response status code: ${response.statusCode}');
      print(' SAHAr 📄 MRSAHAr ApiProvider: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ MRSAHAr ApiProvider: Login successful');

        String message = 'Login successful';
        dynamic data = response.body;

        if (response.body != null && response.body is Map<String, dynamic>) {
          message = response.body['message'] ?? message;
        }

        return LoginResponse(
          success: true,
          message: message,
          data: data,
        );
      } else {
        print(' SAHAr ❌ MRSAHAr ApiProvider: Login failed with status: ${response.statusCode}');

        String errorMessage = 'Login failed';
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            errorMessage = response.body['message'] ?? errorMessage;
          } else if (response.body is String) {
            errorMessage = response.body;
          }
        }

        return LoginResponse(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      print(' SAHAr 💥 MRSAHAr ApiProvider: Login exception: $e');
      print(' SAHAr 📍 MRSAHAr ApiProvider: Stack trace: $stackTrace');

      return LoginResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request) async {
    try {
      print(' SAHAr 🚀 MRSAHAr ApiProvider: Starting forgot password for: ${_globalVars.baseUrl}/api/Drivers/forgot-password');
      print(' SAHAr 📦 MRSAHAr ApiProvider: ForgotPassword Request data: ${request.toJson()}');

      final response = await postData('/api/Drivers/forgot-password', request.toJson());

      print(' SAHAr 📋 MRSAHAr ApiProvider: ForgotPassword response received');
      print(' SAHAr 📊 MRSAHAr ApiProvider: Response status code: ${response.statusCode}');
      print(' SAHAr 📄 MRSAHAr ApiProvider: Response body: ${response.body}');
      print(' SAHAr 📝 MRSAHAr ApiProvider: Response body type: ${response.body.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ MRSAHAr ApiProvider: ForgotPassword successful');

        String message = 'Reset email sent successfully';
        dynamic data = response.body;

        // Handle different response formats
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            // JSON response
            final Map<String, dynamic> bodyMap = response.body;
            message = bodyMap['message'] ?? message;
            data = bodyMap;
            print(' SAHAr 📝 MRSAHAr ApiProvider: JSON response received');
          } else if (response.body is String && response.body.isNotEmpty) {
            // String response
            message = response.body;
            print(' SAHAr 📝 MRSAHAr ApiProvider: String response received');
          } else {
            message = 'Reset email sent successfully';
            print(' SAHAr 📝 MRSAHAr ApiProvider: Default message used');
          }
        }

        return ForgotPasswordResponse(
          success: true,
          message: message,
          data: data,
        );
      } else {
        print(' SAHAr ❌ MRSAHAr ApiProvider: ForgotPassword failed with status: ${response.statusCode}');

        String errorMessage = 'Failed to send reset email';
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            errorMessage = response.body['message'] ?? errorMessage;
          } else if (response.body is String && response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }

        return ForgotPasswordResponse(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      print(' SAHAr 💥 MRSAHAr ApiProvider: ForgotPassword exception: $e');
      print(' SAHAr 📍 MRSAHAr ApiProvider: Stack trace: $stackTrace');

      return ForgotPasswordResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  Future<ResetPasswordResponse> resetPassword(ResetPasswordRequest request) async {
    try {
      print(' SAHAr 🚀 ApiProvider: Starting reset password for: ${_globalVars.baseUrl}/api/Drivers/reset-password');
      print(' SAHAr 📦 ApiProvider: ResetPassword Request data: ${request.toJson()}');

      final response = await postData('/api/Drivers/reset-password', request.toJson());

      print(' SAHAr 📋 ApiProvider: ResetPassword response received');
      print(' SAHAr 📊 ApiProvider: Response status code: ${response.statusCode}');
      print(' SAHAr 📄 ApiProvider: Response body: ${response.body}');
      print(' SAHAr 📝 ApiProvider: Response body type: ${response.body.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ ApiProvider: ResetPassword successful');

        String message = 'Password reset successfully';
        dynamic data = response.body;

        // Handle different response formats
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            // JSON response
            final Map<String, dynamic> bodyMap = response.body;
            message = bodyMap['message'] ?? message;
            data = bodyMap;
            print(' SAHAr 📝 ApiProvider: JSON response received');
          } else if (response.body is String && response.body.isNotEmpty) {
            // String response
            message = response.body;
            print(' SAHAr 📝 ApiProvider: String response received');
          } else {
            message = 'Password reset successfully';
            print(' SAHAr 📝 ApiProvider: Default message used');
          }
        }

        return ResetPasswordResponse(
          success: true,
          message: message,
          data: data,
        );
      } else {
        print(' SAHAr ❌ ApiProvider: ResetPassword failed with status: ${response.statusCode}');

        String errorMessage = 'Failed to reset password';
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            errorMessage = response.body['message'] ?? errorMessage;
          } else if (response.body is String && response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }

        return ResetPasswordResponse(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      print(' SAHAr 💥 ApiProvider: ResetPassword exception: $e');
      print(' SAHAr 📍 ApiProvider: Stack trace: $stackTrace');

      return ResetPasswordResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

}