import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/pages/onboarding.dart';
import 'package:budget/providers/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final settings = context.read<SettingsService>();

    if (settings.displayName is String && settings.displayName!.isNotEmpty) {
      _nameController.text = settings.displayName!;
    }
  }

  void onSubmit() {
    final settings = context.read<SettingsService>();

    var newName = _nameController.text.trim();

    if (newName != settings.displayName && newName.isNotEmpty) {
      settings.displayName = newName;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        actions: [IconButton(icon: Icon(Icons.check), onPressed: onSubmit)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              TextInputEditField(
                label: 'Display Name',
                controller: _nameController,
              ),
              // Row(
              //   children: [
              //     Text(
              //       'Starting weekday',
              //       style: Theme.of(context).textTheme.bodyLarge,
              //     ),
              //     Spacer(),
              //     DropdownMenu<String>(
              //       initialSelection: 'Sunday',
              //       dropdownMenuEntries: [
              //         DropdownMenuEntry(value: 'Monday', label: 'Monday'),
              //         DropdownMenuEntry(value: 'Sunday', label: 'Sunday'),
              //       ],
              //     ),
              //   ],
              // ),
              Divider(),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.errorContainer,
                child: InkWell(
                  onTap: () async {
                    // Navigating back to the main screen should be handled
                    // by NavManager. Still get rid of the settings page though
                    await Supabase.instance.client.auth.signOut();

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Log out',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
              ExternalSettingsButton(
                text: 'View help',
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => Scaffold(
                              appBar: AppBar(title: Text('Help')),
                              body: SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: OnboardingInformation(),
                                ),
                              ),
                            ),
                      ),
                    ),
              ),
              ExternalSettingsButton(
                text: 'View licenses',
                onTap: () => showLicensePage(context: context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExternalSettingsButton extends StatelessWidget {
  final Function() onTap;
  final String text;

  const ExternalSettingsButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(text, style: Theme.of(context).textTheme.bodyLarge),
              Spacer(),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
