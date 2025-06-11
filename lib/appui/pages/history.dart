import 'dart:async';
import 'dart:collection';

import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/appui/pages/transaction_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

DateTime getUtcDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day);
}

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  late final AppDatabase _db;
  late final ValueNotifier<List<Transaction>> _selectedEvents;

  LinkedHashMap<DateTime, List<Transaction>> _events = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => getUtcDate(key).hashCode,
  );

  StreamSubscription<List<Transaction>>? _transactionsSubscription;

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();

    _db = context.read<AppDatabase>();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay));

    _initStreamSubscription(_focusedDay);
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    _selectedEvents.dispose();
    super.dispose();
  }

  void _initStreamSubscription(DateTime day) {
    setState(() {
      _events.clear();
      _selectedEvents.value = _getEventsForDay(_selectedDay);
    });

    _transactionsSubscription?.cancel();

    final firstDayOfMonth = DateTime.utc(day.year, day.month, 1);
    final lastDayOfMonth = DateTime.utc(day.year, day.month + 1, 0);
    final start = firstDayOfMonth;
    final end = lastDayOfMonth.add(const Duration(days: 1));

    _transactionsSubscription = _db.transactionDao
        .watchTransactionsPage(
          filters: [DateRangeFilter(DateTimeRange(start: start, end: end))],
        )
        .listen((transactionsInRange) {
          final newEvents = LinkedHashMap<DateTime, List<Transaction>>(
            equals: isSameDay,
            hashCode: (key) => getUtcDate(key).hashCode,
          );
          for (final transaction in transactionsInRange) {
            final dateKey = getUtcDate(transaction.date);
            final dayEvents = newEvents.putIfAbsent(dateKey, () => []);
            dayEvents.add(transaction);
          }

          if (mounted) {
            setState(() {
              _events = newEvents;
            });

            _selectedEvents.value = _getEventsForDay(_selectedDay);
          }
        }); // TODO: Error handler
  }

  List<Transaction> _getEventsForDay(DateTime day) =>
      _events[getUtcDate(day)] ?? [];

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    if (focusedDay.month == _focusedDay.month &&
        focusedDay.year == focusedDay.year) {
      setState(() {
        _focusedDay = focusedDay;
      });
      return;
    }

    _focusedDay = focusedDay;

    _initStreamSubscription(focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Text(
                'Your activity',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionSearchPage(),
                      ),
                    ),
              ),
            ],
          ),
        ),
        TableCalendar(
          firstDay: DateTime.utc(2010, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          onPageChanged: _onPageChanged,
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            markersAutoAligned: false,
            markersAlignment: Alignment.topRight,
            markerMargin: EdgeInsets.all(4.0),
            markersMaxCount: 1,
            markerSize: 12,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            todayDecoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ValueListenableBuilder<List<Transaction>>(
            valueListenable: _selectedEvents,
            builder:
                (context, value, _) => ObjectsList(
                  objects:
                      value
                          .map(
                            (t) => TransactionTileableAdapter(
                              t,
                              onMultiselect: (_, _) {},
                            ),
                          )
                          .toList(),
                ),
          ),
        ),
      ],
    );
  }
}
