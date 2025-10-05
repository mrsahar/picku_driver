import 'package:flutter/material.dart';
import 'package:get/get.dart';


class ProfileForm extends StatelessWidget {
  const ProfileForm({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Fetch the app theme
    final textTheme = theme.textTheme; // Access text styles
    final colorScheme = theme.colorScheme; // Access colors

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,),

        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subheading
              Text(
                'Don’t worry, only you can see your personal data. No one else will be able to see it.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
        
              // Name Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Jenny Wilson',
                  labelStyle: textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
        
              // Email Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@gmail.com',
                  labelStyle: textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
        
              // Phone Number Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 Enter Phone Number',
                  labelStyle: textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
        
              // Gender Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((label) => DropdownMenuItem(
                  value: label,
                  child: Text(label),
                ))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 20),
        
              // City Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'City You Drive In',
                  labelStyle: textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                ),
                items: ['Jersey City, New Jersey']
                    .map((label) => DropdownMenuItem(
                  value: label,
                  child: Text(label),
                ))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 20),
        
              // Terms & Conditions
              Row(
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (value) {},
                    activeColor: colorScheme.primary,
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground,
                        ),
                        children: [
                          const TextSpan(text: 'By Accept, you agree to Company '),
                          TextSpan(
                            text: 'Terms & Condition',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Handle continue
              //Get.to(() => const RequiredDocuments());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              'Continue',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
