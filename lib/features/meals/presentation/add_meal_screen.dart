import 'package:flutter/material.dart';
import '../../../core/models/ai_food_result.dart';
import '../../../core/services/language_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal.dart';
import '../data/meal_repository.dart';
import '../../scan/presentation/scan_food_screen.dart';

import '../../../core/utils/responsive.dart';

class AddMealScreen extends StatefulWidget {
  final String mealType;
  final Meal? meal;
  final AIFoodResult? aiResult;

  const AddMealScreen({
    super.key,
    this.mealType = 'Breakfast',
    this.meal,
    this.aiResult,
  });

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final foodController = TextEditingController();
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();
  final quantityController = TextEditingController();

  late String selectedMealType;

  final MealRepository repository = MealRepository.instance;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    selectedMealType = widget.mealType.isNotEmpty ? widget.mealType : 'Breakfast';

    if (widget.meal != null) {
      foodController.text = widget.meal!.foodName;
      caloriesController.text = widget.meal!.calories.toString();
      proteinController.text = widget.meal!.protein.toString();
      carbsController.text = widget.meal!.carbs.toString();
      fatController.text = widget.meal!.fat.toString();
      quantityController.text = widget.meal!.quantity.toString();
      selectedMealType = widget.meal!.mealType;
    }

    if (widget.aiResult != null) {
      foodController.text = widget.aiResult!.foodName;
      caloriesController.text = widget.aiResult!.calories.toString();
      proteinController.text = widget.aiResult!.protein.toString();
      carbsController.text = widget.aiResult!.carbs.toString();
      fatController.text = widget.aiResult!.fat.toString();
      quantityController.text = widget.aiResult!.quantity.toString();
    }
  }

  @override
  void dispose() {
    foodController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> saveMeal() async {
    if (foodController.text.isEmpty ||
        caloriesController.text.isEmpty ||
        proteinController.text.isEmpty ||
        carbsController.text.isEmpty ||
        fatController.text.isEmpty ||
        quantityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(LanguageService.tr("Please fill all fields"))));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final meal = Meal(
        id:
            widget.meal?.id ??
            FirebaseFirestore.instance.collection('temp').doc().id,
        userId: FirebaseAuth.instance.currentUser!.uid,
        mealType: selectedMealType,
        foodName: foodController.text.trim(),
        calories: double.parse(caloriesController.text),
        protein: double.parse(proteinController.text),
        carbs: double.parse(carbsController.text),
        fat: double.parse(fatController.text),
        quantity: double.parse(quantityController.text),
        createdAt: widget.meal?.createdAt ?? DateTime.now(),
      );

      if (widget.meal == null) {
        await repository.addMeal(meal);
      } else {
        await repository.updateMeal(meal);
      }
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(bool isDark, Color primaryColor) {
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: mealTypes.map((type) {
          final isSelected = selectedMealType.toLowerCase() == type.toLowerCase();
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedMealType = type;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  LanguageService.tr(type),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isDark
                            ? Colors.white70
                            : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF10B981) : const Color(0xFF047857);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.meal == null
              ? "${LanguageService.tr('Add Meal')} - ${LanguageService.tr(selectedMealType)}"
              : "${LanguageService.tr('Edit')} ${LanguageService.tr(selectedMealType)}",
        ),
      ),
      body: ResponsiveContentConstrained(
        maxWidth: Responsive.maxFormWidth(context),
        enableScroll: false,
        child: ListView(
          children: [
            // Meal Type Selector Chips
            _buildMealTypeSelector(isDark, primaryColor),

            // AI Scan Feature Banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanFoodScreen(mealType: selectedMealType),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService.tr("✨ Auto-fill with AI Scanner"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LanguageService.tr("Take a photo of your meal to scan calories & macros automatically"),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            TextField(
              controller: foodController,
              decoration: InputDecoration(
                labelText: LanguageService.tr("Food Name"),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            buildField(LanguageService.tr("Calories"), caloriesController),

            buildField(LanguageService.tr("Protein (g)"), proteinController),

            buildField(LanguageService.tr("Carbs (g)"), carbsController),

            buildField(LanguageService.tr("Fat (g)"), fatController),

            buildField(LanguageService.tr("Quantity"), quantityController),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveMeal,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        widget.meal != null
                            ? "${LanguageService.tr('Edit')} ${widget.mealType}"
                            : widget.aiResult != null
                            ? LanguageService.tr("Confirm AI Meal")
                            : "${LanguageService.tr('Add')} ${widget.mealType}",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
