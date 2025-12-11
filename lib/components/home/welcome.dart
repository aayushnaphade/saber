import 'package:flutter/material.dart';
import 'package:saber/data/prefs.dart';

class Welcome extends StatelessWidget {
  const Welcome({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  String _getTimeOfDay() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom illustration using shapes and gradients
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.3),
                    colorScheme.secondaryContainer.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Brain/Mind illustration
                  Positioned(
                    top: 60,
                    left: 60,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withOpacity(0.2),
                            colorScheme.tertiary.withOpacity(0.2),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.psychology_outlined,
                          size: 80,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Decorative elements
                  Positioned(
                    top: 40,
                    right: 50,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.secondary.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 50,
                    left: 30,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.tertiary.withOpacity(0.3),
                      ),
                    ),
                  ),
                  // Sparkle/star elements
                  Positioned(
                    top: 20,
                    left: 120,
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary.withOpacity(0.5),
                      size: 24,
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    right: 80,
                    child: Icon(
                      Icons.stars_rounded,
                      color: colorScheme.secondary.withOpacity(0.5),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Greeting
            Text(
              _getGreeting(),
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Time
            ValueListenableBuilder(
              valueListenable: stows.supabaseUserEmail,
              builder: (context, email, _) {
                return Column(
                  children: [
                    Text(
                      _getTimeOfDay(),
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        email,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // App name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'SynapseAI',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mental Health Documentation',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
