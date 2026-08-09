import 'package:flutter/material.dart';
import '../models/meal.dart';

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
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.restaurant)),
        title: Text(
          meal.foodName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${meal.calories.toStringAsFixed(0)} kcal"),
            Text("P ${meal.protein}g • C ${meal.carbs}g • F ${meal.fat}g"),
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
