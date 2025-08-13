import 'package:flutter/material.dart';
import 'package:pick_u_driver/authentication/widget/login_footer_widget.dart';
import 'package:pick_u_driver/authentication/widget/login_form.dart';
import 'package:pick_u_driver/authentication/widget/login_header_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return   Scaffold(
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoginHeaderWidget(),
                LoginForm(),
                LoginFooterWidget(),
              ],
            ),
          ),
        ),
      );
  }
}
