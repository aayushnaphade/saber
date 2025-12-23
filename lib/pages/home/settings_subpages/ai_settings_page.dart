import 'package:flutter/material.dart';
import 'package:saber/components/settings/settings_subtitle.dart';
import 'package:saber/components/settings/settings_switch.dart';
import 'package:saber/data/prefs.dart';

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Settings'),
      ),
      body: ListView(
        children: [
          const SettingsSubtitle(subtitle: 'Extraction Settings'),
          SettingsSwitch(
            pref: stows.exactExtraction,
            title: 'Exact Extraction',
            subtitle: 'Extract information exactly as it appears in the source.',
            icon: Icons.content_cut,
          ),
          const SizedBox(height: 16),
          const SettingsSubtitle(subtitle: 'Notes Generation'),
          SettingsSwitch(
            pref: stows.aiNotesEnabled,
            title: 'Enable AI Notes',
            subtitle: 'Automatically generate notes using AI.',
            icon: Icons.auto_awesome,
          ),
        ],
      ),
    );
  }
}
