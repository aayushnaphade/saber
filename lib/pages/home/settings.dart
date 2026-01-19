import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/settings/settings_button.dart';
import 'package:saber/components/settings/supabase_profile.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/settings_subpages/ai_settings_page.dart';
import 'package:saber/pages/home/settings_subpages/app_settings_page.dart';
import 'package:stow/stow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<bool?> showResetDialog({
    required BuildContext context,
    required Stow pref,
    required String prefTitle,
  }) async {
    if (pref.value == pref.defaultValue) return null;
    return await showDialog(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.settings.reset.title),
        content: Text(prefTitle),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              pref.value = pref.defaultValue;
              Navigator.of(context).pop(true);
            },
            child: Text(t.settings.reset.button),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    stows.locale.addListener(onChanged);
    UpdateManager.status.addListener(onChanged);
    super.initState();
  }

  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverAppBar(
              collapsedHeight: kToolbarHeight,
              expandedHeight: 200,
              pinned: true,
              scrolledUnderElevation: 1,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  t.home.titles.settings,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  bottom: 16,
                ),
              ),
              actions: [
                // Theme Toggle
                ValueListenableBuilder(
                  valueListenable: stows.appTheme,
                  builder: (context, currentMode, _) {
                    IconData icon;
                    String tooltip;
                    if (currentMode == ThemeMode.light) {
                      icon = Icons.light_mode;
                      tooltip = 'Switch to Dark Mode';
                    } else if (currentMode == ThemeMode.dark) {
                      icon = Icons.dark_mode;
                      tooltip = 'Switch to System Mode';
                    } else {
                      icon = Icons.brightness_auto;
                      tooltip = 'Switch to Light Mode';
                    }

                    return IconButton(
                      tooltip: tooltip,
                      icon: Icon(icon),
                      onPressed: () {
                        final currentIndex = ThemeMode.values.indexOf(
                          currentMode,
                        );
                        final nextIndex =
                            (currentIndex + 1) % ThemeMode.values.length;
                        stows.appTheme.value = ThemeMode.values[nextIndex];
                      },
                    );
                  },
                ),
                if (UpdateManager.status.value != UpdateStatus.upToDate)
                  IconButton(
                    tooltip: t.home.tooltips.showUpdateDialog,
                    icon: const Icon(Icons.system_update),
                    onPressed: () {
                      UpdateManager.showUpdateDialog(
                        context,
                        userTriggered: true,
                      );
                    },
                  ),
              ],
            ),
          ),
          SliverSafeArea(
            sliver: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SliverList.list(
      children: [
        const SupabaseProfile(),
        ValueListenableBuilder(
          valueListenable: stows.receptionMode,
          builder: (context, value, _) {
            return SwitchListTile(
              title: const Text('Reception Mode'),
              subtitle: const Text('Enable simplified interface for reception'),
              value: value,
              onChanged: (newValue) {
                // Dummy toggle - does nothing for now
                stows.receptionMode.value = newValue;
              },
              secondary: const Icon(Icons.desk),
            );
          },
        ),
        _buildFeedbackForm(),
        const SizedBox(height: 16),
        SettingsButton(
          title: 'App Settings',
          subtitle: 'General, Editor, Theme, etc.',
          icon: Icons.settings_applications,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AppSettingsPage()),
            );
          },
        ),
        SettingsButton(
          title: 'AI Settings',
          subtitle: 'Exact Extraction, AI Notes',
          icon: Icons.psychology,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AiSettingsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 5, child: SupabaseProfile()),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: stows.receptionMode,
                    builder: (context, value, _) {
                      return SwitchListTile(
                        title: const Text('Reception Mode'),
                        subtitle: const Text('Enable simplified interface for reception'),
                        value: value,
                        onChanged: (newValue) {
                          // Dummy toggle - does nothing for now
                          stows.receptionMode.value = newValue;
                        },
                        secondary: const Icon(Icons.desk),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFeedbackForm(),
                  const SizedBox(height: 16),
                  SettingsButton(
                    title: 'App Settings',
                    subtitle: 'General, Editor, Theme, etc.',
                    icon: Icons.settings_applications,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AppSettingsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SettingsButton(
                    title: 'AI Settings',
                    subtitle: 'Exact Extraction, AI Notes',
                    icon: Icons.psychology,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AiSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    final feedbackController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.feedback, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Feedback & Suggestions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share your thoughts, ideas, or report issues...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final feedback = feedbackController.text.trim();
                  if (feedback.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your feedback'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  try {
                    await Supabase.instance.client.from('feedback').insert({
                      'user_id': Supabase.instance.client.auth.currentUser?.id,
                      'feedback': feedback,
                      'created_at': DateTime.now().toIso8601String(),
                    });

                    feedbackController.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your feedback!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit feedback: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Submit Feedback'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    stows.locale.removeListener(onChanged);
    UpdateManager.status.removeListener(onChanged);
    super.dispose();
  }
}
