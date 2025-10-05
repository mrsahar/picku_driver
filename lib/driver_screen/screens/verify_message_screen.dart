import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

import '../main_map.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

enum VerificationStatus { pending, verified, rejected }
 

class VerifyMessageScreen extends StatelessWidget {
  final VerificationStatus status;
  final String? rejectionReason;

  const VerifyMessageScreen({
    super.key,
    this.status = VerificationStatus.pending,
    this.rejectionReason,
  });

  IconData _getStatusIcon() {
    switch (status) {
      case VerificationStatus.verified:
        return LineAwesomeIcons.check_circle_solid;
      case VerificationStatus.rejected:
        return LineAwesomeIcons.exclamation_circle_solid;
      case VerificationStatus.pending:
        return LineAwesomeIcons.clock;
    }
  }

  String _getTitle() {
    switch (status) {
      case VerificationStatus.verified:
        return "All Set!";
      case VerificationStatus.rejected:
        return "Verification Required";
      case VerificationStatus.pending:
        return "Under Review";
    }
  }

  String _getSubtitle() {
    switch (status) {
      case VerificationStatus.verified:
        return "Your account has been verified successfully. You're ready to hit the road!";
      case VerificationStatus.rejected:
        return rejectionReason ??
            "We need you to resubmit your documents. Please review the requirements and upload clear, valid documents.";
      case VerificationStatus.pending:
        return "We're reviewing your documents. This usually takes 24-48 hours. We'll notify you once the review is complete.";
    }
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
              MColor.primaryNavy.withOpacity(0.95),
              MColor.primaryNavy,
              Colors.black,
            ]
                : [
              MColor.primaryNavy.withOpacity(0.85),
              MColor.primaryNavy,
              MColor.primaryNavy.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo
                Image.asset(
                  "assets/img/logo.png",
                  width: context.width * 0.5,
                  fit: BoxFit.fitWidth,
                ),

                const Spacer(),

                // Status Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    size: 60,
                    color: MColor.primaryNavy,
                  ),
                ),

                const SizedBox(height: 40),

                // Status Message
                Column(
                  children: [
                    Text(
                      _getTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _getSubtitle(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Action Buttons
                _buildActionButton(),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (status) {
      case VerificationStatus.verified:
        return Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Get.to(() => const MainMap());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MColor.primaryNavy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Continue to Dashboard",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  LineAwesomeIcons.arrow_right_solid,
                  size: 20,
                ),
              ],
            ),
          ),
        );

      case VerificationStatus.rejected:
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                //primaryNavy  Get.to(() => const VerificationPage());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MColor.primaryNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Resubmit Documents",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      LineAwesomeIcons.redo_solid,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Contact support
              },
              child: Text(
                "Contact Support",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        );

      case VerificationStatus.pending:
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: OutlinedButton(
                onPressed: () {
                  Get.back();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Back to Home",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "We'll notify you via email",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        );
    }
  }
}
