import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/utils/enums.dart';
import 'package:flutter/material.dart';

class TopContainers extends StatefulWidget {
  const TopContainers({super.key});

  @override
  State<TopContainers> createState() => _TopContainersState();
}

class _TopContainersState extends State<TopContainers> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Row(
            spacing: 12.0,
            children: [
              Text('Top', style: Theme.of(context).textTheme.headlineMedium),
              Expanded(
                child: DropdownMenu(
                  textStyle: Theme.of(context).textTheme.headlineMedium,
                  dropdownMenuEntries: [
                    DropdownMenuEntry(label: 'This', value: 'that'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
