import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/shift_application_controller.dart';
import 'package:pick_u_driver/utils/theme/app_theme.dart';

class ShiftApplicationPage extends StatelessWidget {
  final ShiftApplicationController controller = Get.put(ShiftApplicationController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply for Shift'),
        centerTitle: true,
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: controller.refreshShifts,
          ),
        ],
      ),
      body: Obx(() {
        // Show loading state
        if (controller.isLoading.value && controller.availableShifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading available shifts...'),
              ],
            ),
          );
        }

        // Show empty state
        if (!controller.isLoading.value && controller.availableShifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No shifts available',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text(
                  'Please check back later for new shifts',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refreshShifts,
                  child: Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shifts Available (${controller.availableShifts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (controller.isLoading.value)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              SizedBox(height: 16),

              // Shift options
              Column(
                children: controller.availableShifts.map((shift) {
                  bool isSelected = controller.selectedShift.value == shift.shiftId;

                  // Check if this shift has been applied for
                  final application = controller.getApplicationForShift(shift.shiftId);
                  final hasApplied = application != null;
                  final canApply = controller.canApplyForShift(shift.shiftId);

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: canApply ? () => controller.selectShift(shift.shiftId) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: hasApplied
                              ? Colors.grey.withOpacity(0.1)
                              : isSelected
                              ? MAppTheme.trackingOrange.withOpacity(0.1)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasApplied
                                ? Colors.grey.withOpacity(0.3)
                                : isSelected
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
                                color: hasApplied
                                    ? Colors.grey.withOpacity(0.2)
                                    : isSelected
                                    ? MAppTheme.trackingOrange.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasApplied ? Icons.check_circle : shift.icon,
                                color: hasApplied
                                    ? controller.getShiftStatusColor(shift.shiftId)
                                    : isSelected
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          shift.title,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: hasApplied
                                                ? Colors.grey.withOpacity(0.7)
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      // Show status badge if applied
                                      if (hasApplied) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: controller.getShiftStatusColor(shift.shiftId)?.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            controller.getShiftStatus(shift.shiftId) ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: controller.getShiftStatusColor(shift.shiftId),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${shift.maxDriverCount} slots',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    shift.formattedTime,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: hasApplied
                                          ? Colors.grey.withOpacity(0.6)
                                          : isSelected
                                          ? MAppTheme.trackingOrange
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    shift.formattedDate,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: hasApplied
                                          ? Colors.grey.withOpacity(0.5)
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  if (shift.description.isNotEmpty) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      hasApplied
                                          ? 'Status: ${controller.getShiftStatus(shift.shiftId)}'
                                          : shift.displayDescription,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: hasApplied
                                            ? controller.getShiftStatusColor(shift.shiftId)
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: hasApplied ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected && canApply)
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
              ),

              SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (controller.isSubmitting.value ||
                      controller.selectedShift.value.isEmpty ||
                      !controller.canApplyForShift(controller.selectedShift.value))
                      ? null
                      : controller.submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (controller.selectedShift.value.isNotEmpty &&
                        controller.canApplyForShift(controller.selectedShift.value))
                        ? null
                        : Colors.grey.withOpacity(0.3),
                  ),
                  child: controller.isSubmitting.value
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    _getSubmitButtonText(controller),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

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
        );
      }      ),
    );
  }

  // Helper method to get submit button text
  String _getSubmitButtonText(ShiftApplicationController controller) {
    if (controller.selectedShift.value.isEmpty) {
      return 'Select a Shift';
    }

    if (!controller.canApplyForShift(controller.selectedShift.value)) {
      final status = controller.getShiftStatus(controller.selectedShift.value);
      return 'Already Applied ($status)';
    }

    return 'Submit Application';
  }
}