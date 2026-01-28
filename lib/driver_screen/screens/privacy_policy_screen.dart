import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/privacy_policy_controller.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PrivacyPolicyController>()
        ? Get.find<PrivacyPolicyController>()
        : Get.put(PrivacyPolicyController());

    return Scaffold(
      backgroundColor: MColor.lightBg,
      appBar: PickUAppBar(
        title: "Privacy Policy",
        onBackPressed: () => Get.back(),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: MColor.primaryNavy),
            onPressed: controller.refreshPolicy,
          ),
        ],
      ),
      body: Obx(() {
        print('PrivacyPolicyScreen: Rendering - isLoading=${controller.isLoading}, hasPolicy=${controller.hasPolicy}, hasContent=${controller.hasContent}');

        if (controller.isLoading) {
          return _buildLoadingView();
        }

        if (controller.errorMessage.isNotEmpty) {
          return _buildErrorView(controller);
        }

        if (!controller.hasPolicy || !controller.hasContent) {
          return _buildEmptyView();
        }

        return _buildPolicyContent(controller);
      }),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: MColor.primaryNavy),
          const SizedBox(height: 16),
          Text(
            'Loading privacy policy...',
            style: TextStyle(fontSize: 14, color: MColor.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(PrivacyPolicyController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: MColor.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: MColor.mediumGrey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: controller.refreshPolicy,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MColor.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: MColor.mediumGrey),
          const SizedBox(height: 16),
          Text(
            'No Privacy Policy Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MColor.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Privacy policy content is not available at the moment',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: MColor.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyContent(PrivacyPolicyController controller) {
    final policy = controller.privacyPolicy!;

    print('_buildPolicyContent: Building policy content for: ${policy.title}');
    print('_buildPolicyContent: Content length: ${policy.content?.length ?? 0}');

    // Simple scrollable text view
    return RefreshIndicator(
      color: MColor.primaryNavy,
      onRefresh: controller.refreshPolicy,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          policy.content ?? 'No content available',
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            color: MColor.darkGrey,
          ),
        ),
      ),
    );
  }

}
