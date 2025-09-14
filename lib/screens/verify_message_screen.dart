import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/driver_screen/new_user/new_profile_screen.dart';

class VerifyMessageScreen extends StatefulWidget {
  const VerifyMessageScreen({super.key});

  @override
  State<VerifyMessageScreen> createState() => _VerifyMessageScreenState();
}

class _VerifyMessageScreenState extends State<VerifyMessageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            "assets/img/otp_bg.png",
            width: double.maxFinite,
            height: double.maxFinite,
            fit: BoxFit.fitWidth,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 80,
              ),
              Image.asset(
                "assets/img/logo.png",
                width: context.width * 0.7,
                fit: BoxFit.fitWidth,
              ),
              const Spacer(),
              Text(
                "You Account\nHas Been Verified\nSuccessfully",
                textAlign: TextAlign.center,
                style: GoogleFonts.agbalumo(color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white, fontSize: 36),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                   Get.to(() => const ProfileForm());
                },
                child: const Icon(LineAwesomeIcons.arrow_right_solid),
              ),
              const SizedBox(
                height: 80,
              ),
            ],
          )
        ],
      ),
    );
  }
}
