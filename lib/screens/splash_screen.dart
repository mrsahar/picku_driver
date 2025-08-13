import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/screens/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingPageData> pages = [
    OnboardingPageData(
      image: "assets/img/container1.jpg",
      title: "Get Onboard and Start, Accepting Rides Instantly",
      subtitle: "It's short, direct, and captures the essence of getting started quickly. What do you think?",
      buttonText: "Next",
    ),
    OnboardingPageData(
      image: "assets/img/container2.jpg",
      title: "Effortlessly Monitor Your Booking Schedule.",
      subtitle: "\"Stay Organized and On Time with Ease\"? It captures the essence of effortlessly managing your booking schedule. What do you think?",
      buttonText: "Next",
    ),
    OnboardingPageData(
      image: "assets/img/container3.jpg",
      title: "Keep Tabs on Your Earnings with Ease",
      subtitle: "It’s concise and captures the essence of your message. What do you think?",
      buttonText: "Get started",
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Precache images here to avoid the MediaQuery error
    for (var page in pages) {
      precacheImage(AssetImage(page.image), context);
    }
  }

  void _nextPage() {
    if (_currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      print("Onboarding Completed");
      Get.to(() => const WelcomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return OnboardingPage(data: pages[index]);
            },
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentIndex == index ? 20 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? theme.primaryColor
                            : theme.primaryColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        _pageController.jumpToPage(pages.length - 1);
                      },
                      child: Text(
                        "Skip",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.amberAccent,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(pages[_currentIndex].buttonText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class OnboardingPageData {
  final String image;
  final String title;
  final String subtitle;
  final String buttonText;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.buttonText,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(data.image),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.3),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
