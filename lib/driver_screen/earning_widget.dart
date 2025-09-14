import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:pick_u_driver/driver_screen/main_map.dart';

class TodayEarningsWidget extends StatelessWidget {
  const TodayEarningsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use the specific color for the container
    const containerColor = Color(0xff242424);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Earned",
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.to(() => const MainMap());
            // Add back button functionality
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatTile(
                    title: 'Total Hour',
                    value: '01',
                    theme: theme,
                    textColor: isDarkMode
                        ? Colors.white // White in dark mode
                        : theme.colorScheme.onPrimary, isDark: isDarkMode, // Primary color in light mode
                  ),
                  SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      color: theme.colorScheme.primary,
                      width: 1.0,
                      thickness: 1.0,
                    ),
                  ),
                  _StatTile(
                    title: 'Total Miles',
                    value: '80',
                    theme: theme,
                    textColor: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onPrimary, isDark: isDarkMode,
                  ),
                  SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      color: theme.colorScheme.onPrimary,
                      width: 1.0,
                      thickness: 1.0,
                    ),
                  ),
                  _StatTile(
                    title: 'Earning (\$)',
                    value: '\$100',
                    theme: theme,
                    textColor: isDarkMode
                        ? Colors.white
                        : theme.colorScheme.onPrimary, isDark: isDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // List of Trips
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => Divider(
                  color: theme.dividerColor,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundImage: AssetImage("assets/img/u2.png"),
                    ),
                    title: Text(
                      'Byron Barlow',
                      style: textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      "4.5 Miles | 10 Min\'s | \$58.00",
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    onTap: () {
                      // Add navigation or action here
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final ThemeData theme;
  final Color textColor;
  final bool isDark;// Add dynamic text color

  const _StatTile({
    required this.title,
    required this.value,
    required this.theme,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark? Colors.black :Colors.white, // Apply dynamic text color
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor, // Apply dynamic text color
          ),
        ),
      ],
    );
  }
}
