import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/login_controller.dart';
import 'package:pick_u_driver/routes/app_routes.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    // Keep the controller alive during route transitions; otherwise a TextField
    // can try to read its controller after GetX disposes it.
    _controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController(), permanent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _controller.formKey,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20 - 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 25,
            ),
            // Email Input Field
            TextFormField(
              controller: _controller.emailController,
              validator: _controller.validateEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: "Enter Email Address",
                hintText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            // Password Input Field
            Obx(() => TextFormField(
              controller: _controller.passwordController,
              validator: _controller.validatePassword,
              obscureText: !_controller.isPasswordVisible.value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                labelText: "Enter Password",
                hintText: "Password",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _controller.togglePasswordVisibility,
                  icon: Icon(
                    _controller.isPasswordVisible.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            )),
            const SizedBox(height: 30 - 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.FORGOT_PASSWORD_SCREEN);
                  },
                  child: const Text("Forgot Password?")),
            ),
            // Login Button (connected to controller with loading state)
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _controller.isLoading.value
                    ? null
                    : () {
                  _controller.login(context);
                },
                child: _controller.isLoading.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Login".toUpperCase()),
              ),
            )),
          ],
        ),
      ),
    );
  }
}