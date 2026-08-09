import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            splashRadius: 24,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
          ),

          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  DateFormat('EEE, d MMM yyyy').format(selectedDate),
                  key: ValueKey(selectedDate),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          IconButton(
            splashRadius: 24,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isToday ? Colors.grey : Colors.black,
            ),
            onPressed: isToday ? null : onNext,
          ),
        ],
      ),
    );
  }
}