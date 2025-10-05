import 'package:flutter/material.dart';
import 'package:flutter_dash/flutter_dash.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

class BankAccountDetailsScreen extends StatefulWidget {
  const BankAccountDetailsScreen({super.key});


  @override
  _BankAccountDetailsScreenState createState() => _BankAccountDetailsScreenState();
}

class _BankAccountDetailsScreenState extends State<BankAccountDetailsScreen> {
  final List<Map<String, dynamic>> _uploadedImages =
  []; // Stores uploaded images with labels

  void _removeImage(int index) {
    setState(() {
      _uploadedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Account Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guidelines Section
              const SizedBox(height: 8),
              _buildGuideline(
                theme: theme,
                text:
                "Upload Bank Document (Passbook, Cancelled Cheque, Bank Statement, or Digital Account Screenshot)",
              ),
              const SizedBox(height: 8),
              _buildGuideline(
                theme: theme,
                text:
                "Upload PDF / JPEG / PNG.",
              ),
              const SizedBox(height: 24),

              // Attach Driving License Section
              Text(
                "Attach Profile Picture",
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: () {}, // Callback to select the image
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final color = Theme.of(context).colorScheme.primary; // Theme-based color

                    // Ensure valid constraints for Dash
                    final double width = constraints.maxWidth.isFinite ? constraints.maxWidth : 300; // Default width
                    const double height = 150; // Fixed height for the container

                    return Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8), // Rounded corners
                      ),
                      child: Stack(
                        children: [
                          // Dashed border - Top
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Dash(
                              direction: Axis.horizontal,
                              length: width, // Bounded width
                              dashLength: 6,
                              dashThickness: 1.5,
                              dashGap: 4,
                              dashColor: color,
                            ),
                          ),

                          // Dashed border - Bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Dash(
                              direction: Axis.horizontal,
                              length: width, // Bounded width
                              dashLength: 6,
                              dashThickness: 1.5,
                              dashGap: 4,
                              dashColor: color,
                            ),
                          ),

                          // Dashed border - Left
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            child: Dash(
                              direction: Axis.vertical,
                              length: height, // Fixed height
                              dashLength: 6,
                              dashThickness: 1.5,
                              dashGap: 4,
                              dashColor: color,
                            ),
                          ),

                          // Dashed border - Right
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            child: Dash(
                              direction: Axis.vertical,
                              length: height, // Fixed height
                              dashLength: 6,
                              dashThickness: 1.5,
                              dashGap: 4,
                              dashColor: color,
                            ),
                          ),

                          // Content of the container
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, color: color, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  "Upload Documents",
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Text(
                "Note: Please upload both sides of Driving License",
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),

              // Uploaded Images Section
              if (_uploadedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _uploadedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        // Display uploaded image
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: _uploadedImages[index]['image'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        // Label
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _uploadedImages[index]['label'],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 20),

              // Done Button
              ElevatedButton(
                onPressed: _uploadedImages.length == 2 // Requires 2 images
                    ? () {
                  // Submit logic here
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Method to Build Guideline Row
  Widget _buildGuideline({required ThemeData theme, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: theme.brightness == Brightness.dark
                ? theme.primaryColorDark // Lighter background for dark mode
                : theme.primaryColor.withOpacity(0.1), // Regular background for light mode
          ),
          child: Icon(
            LineAwesomeIcons.sign_in_alt_solid,
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.secondary // Contrasting color for dark mode
                : theme.primaryColor, // Regular color for light mode
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
