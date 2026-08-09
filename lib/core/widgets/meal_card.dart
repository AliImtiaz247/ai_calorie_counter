import 'package:flutter/material.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final String calories;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onScan;

  const MealCard({
    super.key,
    required this.mealName,
    required this.calories,
    required this.icon,
    required this.onTap,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF22C55E);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Card(
      color: cardBgColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      elevation: isDark ? 4 : 2,
      shadowColor: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primaryColor.withValues(alpha: 0.15),
                child: Icon(icon, color: primaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      calories,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onScan != null) ...[
                ElevatedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                    foregroundColor: primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
