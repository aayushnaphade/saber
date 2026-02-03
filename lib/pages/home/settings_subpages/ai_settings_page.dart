import 'package:flutter/material.dart';
import 'package:saber/components/settings/settings_dropdown.dart';
import 'package:saber/components/settings/settings_subtitle.dart';
import 'package:saber/components/settings/settings_switch.dart';
import 'package:saber/components/theming/adaptive_toggle_buttons.dart';
import 'package:saber/data/prefs.dart';

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Settings')),
      body: ListView(
        children: [
          const SettingsSubtitle(subtitle: 'Report Generation'),
          SettingsDropdown<ReportGenerationModel>(
            pref: stows.reportGenerationModel,
            title: 'Generation Quality',
            subtitle: 'Choose between speed and quality',
            icon: Icons.speed,
            options: [
              ToggleButtonsOption(
                ReportGenerationModel.flash,
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Fast Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Quick reports (~5-10 seconds)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Uses Gemini 3 Flash',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ToggleButtonsOption(
                ReportGenerationModel.pro,
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Deep & Focused Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Highest quality (~20-35 seconds)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Uses Gemini 3 Pro',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SettingsSubtitle(subtitle: 'Extraction Settings'),
          SettingsSwitch(
            pref: stows.exactExtraction,
            title: 'Exact Extraction',
            subtitle:
                'Extract information exactly as it appears in the source.',
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
