import 'package:flutter/material.dart';

Widget CustomerLocation(BuildContext context) {
  final theme = Theme.of(context);
  var brightness = MediaQuery.of(context).platformBrightness;
  final isDarkMode = brightness == Brightness.dark;
  final inputBorderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Material( // Wrap the container in Material
        color: Colors.transparent, // To match the parent background
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.3),
                blurRadius: 10.0,
                offset: const Offset(0, -4), // Shadow at the top
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 3,
                  decoration: BoxDecoration(
                    color: inputBorderColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Customer Location",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "5 mins Away",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Divider(color: theme.dividerColor, thickness: 0.4),
                  // Driver Info Card
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero, // Remove default padding
                          leading: const CircleAvatar(
                            backgroundImage: AssetImage("assets/img/u2.png"), radius: 24,
                          ),
                          title: Text(
                            'Esther Howard',
                            style: theme.textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            'Cash Payment',
                            style: theme.textTheme.bodyMedium,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.message,
                                    color: theme.colorScheme.primary),
                                onPressed: () {
                                  // Add message action
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.phone,
                                    color: theme.colorScheme.primary),
                                onPressed: () {
                                  // Add call action
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20), // Replace Spacer with SizedBox
                        ElevatedButton(
                          onPressed: () {
                            // Add continue action
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
