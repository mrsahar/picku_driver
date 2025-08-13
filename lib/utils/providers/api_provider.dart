import 'package:get/get.dart';
import 'package:pick_u_driver/core/global_variables.dart';

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
      print('API Response: ${response.statusCode} - ${response.bodyString}');
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

  // PUT Request
  Future<Response> putData(String endpoint, Map<String, dynamic> data) async {
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
}