import 'package:flutter/material.dart';
import '../../models/meal.dart';

class MealTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const MealTile({
    super.key,
    required this.meal,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFE7F5E8),
          child: Icon(
            Icons.restaurant_menu,
            color: const Color(0xFF16A34A),
            size: 26,
          ),
        ),
        title: Text(
          meal.foodName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${meal.calories.toStringAsFixed(0)} kcal · Qty ${meal.quantity.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              "P ${meal.protein}g • C ${meal.carbs}g • F ${meal.fat}g",
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == "edit") {
              onEdit();
            } else {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: "edit", child: Text("Edit")),
            PopupMenuItem(value: "delete", child: Text("Delete")),
          ],
        ),
      ),
    );
  }
}
