// lib/app/data/services/user_service.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/app_constants.dart';
import 'package:pick_u_driver/models/User.dart';
import 'package:pick_u_driver/utils/providers/api_provider.dart';

class UserService extends GetxService {
  final ApiProvider _apiProvider = Get.put(ApiProvider());

  Future<List<User>> getUsers() async {
    try {
      final response = await _apiProvider.getData(AppConstants.USERS_ENDPOINT);

      if (response.statusCode == 200) {
        List<dynamic> jsonList = response.body;
        return jsonList.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusText}');
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  Future<User> getUserById(int id) async {
    try {
      final response = await _apiProvider.getData('${AppConstants.USERS_ENDPOINT}/$id');

      if (response.statusCode == 200) {
        return User.fromJson(response.body);
      } else {
        throw Exception('Failed to load user: ${response.statusText}');
      }
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  Future<User> createUser(User user) async {
    try {
      final response = await _apiProvider.postData(
        AppConstants.USERS_ENDPOINT,
        user.toJson(),
      );

      if (response.statusCode == 201) {
        return User.fromJson(response.body);
      } else {
        throw Exception('Failed to create user: ${response.statusText}');
      }
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  Future<User> updateUser(int id, User user) async {
    try {
      final response = await _apiProvider.putData(
        '${AppConstants.USERS_ENDPOINT}/$id',
        user.toJson(),
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.body);
      } else {
        throw Exception('Failed to update user: ${response.statusText}');
      }
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final response = await _apiProvider.deleteData('${AppConstants.USERS_ENDPOINT}/$id');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete user: ${response.statusText}');
      }
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }
}