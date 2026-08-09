import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final Widget child;

  const InfoCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: isDark ? 4 : 2,
      shadowColor: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
