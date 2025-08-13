import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/screens/verify_message_screen.dart';

class OTPScreen extends StatelessWidget {
  const OTPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/img/logo.png"),
            const SizedBox(height: 40.0),
            Text("Verify Code".toUpperCase(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 40.0),
            const Text("Please enter the code we just send to our email support@picku.com", textAlign: TextAlign.center),
            const SizedBox(height: 20.0),
            OtpTextField(
                focusedBorderColor: const Color(0xFFFFC900),
                mainAxisAlignment: MainAxisAlignment.center,
                numberOfFields: 6,
                fillColor: Colors.black.withOpacity(0.1),
                filled: true,
                onSubmit: (code) => print("OTP is => $code")),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () {
                Get.to(() => const VerifyMessageScreen());
              }, child: const Text("Login")),
            ),
          ],
        ),
      ),
    );
  }
}