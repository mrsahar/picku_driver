import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/utils/theme/app_theme.dart';

class ShiftApplicationController extends GetxController {
  RxString selectedShift = ''.obs;
  RxBool isLoading = false.obs;

  final List<ShiftSlot> availableShifts = [
    ShiftSlot(
      id: 'morning',
      title: 'Morning Shift',
      time: '6:00 AM - 2:00 PM',
      description: 'Early start for morning deliveries',
      icon: Icons.wb_sunny,
    ),
    ShiftSlot(
      id: 'afternoon',
      title: 'Afternoon Shift',
      time: '2:00 PM - 10:00 PM',
      description: 'Peak hours with high demand',
      icon: Icons.wb_sunny_outlined,
    ),
    ShiftSlot(
      id: 'night',
      title: 'Night Shift',
      time: '10:00 PM - 6:00 AM',
      description: 'Night deliveries and late orders',
      icon: Icons.nightlight_round,
    ),
  ];

  void selectShift(String shiftId) {
    selectedShift.value = shiftId;
  }

  Future<void> submitApplication() async {
    if (selectedShift.value.isEmpty) {
      Get.snackbar(
        'Selection Required',
        'Please select a shift before submitting',
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    isLoading.value = true;

    // Wait for 2 seconds then show popup
    await Future.delayed(Duration(seconds: 2));

    isLoading.value = false;

    // Always show success popup after 2 seconds
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2C2C2C)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success animation container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 60,
                    color: Colors.green,
                  ),
                ),

                SizedBox(height: 24),

                // Success title
                Text(
                  'Request Submitted Successfully!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : MAppTheme.primaryNavyBlue,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 16),

                // Success message
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MAppTheme.trackingOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MAppTheme.trackingOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        color: MAppTheme.trackingOrange,
                        size: 24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your shift application has been submitted for review.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : MAppTheme.primaryNavyBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You will receive a notification once it\'s approved by our team.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.7)
                              : MAppTheme.primaryNavyBlue.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).brightness == Brightness.dark
                              ? MAppTheme.trackingOrange
                              : MAppTheme.primaryNavyBlue,
                          side: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? MAppTheme.trackingOrange
                                : MAppTheme.primaryNavyBlue,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog only
                        },
                        child: Text('Ok'),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Expanded(
                    //   child: ElevatedButton(
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor: MAppTheme.primaryNavyBlue,
                    //       foregroundColor: Colors.white,
                    //     ),
                    //     onPressed: () {
                    //       Navigator.of(context).pop(); // Close dialog
                    //       Navigator.of(context).pop(); // Go back to previous page
                    //     },
                    //     child: Text('Go Back'),
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ShiftSlot {
  final String id;
  final String title;
  final String time;
  final String description;
  final IconData icon;

  ShiftSlot({
    required this.id,
    required this.title,
    required this.time,
    required this.description,
    required this.icon,
  });
}

class ShiftApplicationPage extends StatelessWidget {
  final ShiftApplicationController controller = Get.put(ShiftApplicationController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply for Shift'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MAppTheme.trackingOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MAppTheme.trackingOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 40,
                    color: MAppTheme.trackingOrange,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Choose Your Shift',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select the shift that works best for your schedule',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Shifts Available section
            Text(
              'Shifts Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),

            // Shift options
            Obx(() => Column(
              children: controller.availableShifts.map((shift) {
                bool isSelected = controller.selectedShift.value == shift.id;

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => controller.selectShift(shift.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MAppTheme.trackingOrange.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? MAppTheme.trackingOrange
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? MAppTheme.trackingOrange.withOpacity(0.2)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              shift.icon,
                              color: isSelected
                                  ? MAppTheme.trackingOrange
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shift.title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  shift.time,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? MAppTheme.trackingOrange
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  shift.description,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: MAppTheme.trackingOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),

            SizedBox(height: 32),

            // Submit button
            Obx(() => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: controller.isLoading.value ? null : controller.submitApplication,
                child: controller.isLoading.value
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  'Submit Application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )),

            SizedBox(height: 16),

            // Info text
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your application will be reviewed by our team. You will receive a notification once your shift request is approved or if any additional information is required.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}