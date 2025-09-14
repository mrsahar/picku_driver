// widgets/driver_profile_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Custom form field widget for better consistency
class ProfileFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final String? helperText;
  final bool isRequired;

  const ProfileFormField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
    this.helperText,
    this.isRequired = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        helperText: helperText,
        helperMaxLines: 2,
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      maxLength: maxLength,
    );
  }
}

// Profile completion card widget
class ProfileCompletionCard extends StatelessWidget {
  final double completionPercentage;
  final VoidCallback? onTap;

  const ProfileCompletionCard({
    Key? key,
    required this.completionPercentage,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isComplete = completionPercentage >= 1.0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green.withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  isComplete ? Icons.check_circle : Icons.person_outline,
                  color: isComplete ? Colors.green : Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? 'Profile Complete' : 'Complete Your Profile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'Your driver profile is complete'
                          : 'Add your details to start driving',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: completionPercentage,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? Colors.green : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${(completionPercentage * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isComplete ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}