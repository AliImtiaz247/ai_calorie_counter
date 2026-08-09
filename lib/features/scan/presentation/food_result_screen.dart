import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/ai_food_result.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/responsive.dart';
import '../../meals/presentation/add_meal_screen.dart';

class FoodResultScreen extends StatefulWidget {
  final File image;
  final AIFoodResult aiResult;
  final String mealType;

  const FoodResultScreen({
    super.key,
    required this.image,
    required this.aiResult,
    required this.mealType,
  });

  @override
  State<FoodResultScreen> createState() => _FoodResultScreenState();
}

class _FoodResultScreenState extends State<FoodResultScreen> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.aiResult.foodName);
    _quantityController = TextEditingController(
      text: widget.aiResult.quantity > 0
          ? widget.aiResult.quantity.round().toString()
          : '100',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark ? const Color(0xFF10B981) : const Color(0xFF047857);
        final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

        return Scaffold(
          appBar: AppBar(
            title: Text(LanguageService.tr("Food Analysis Results")),
            centerTitle: true,
          ),
          body: SafeArea(
            child: ResponsiveContentConstrained(
              maxWidth: Responsive.maxFormWidth(context),
              enableScroll: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Banner Card with Confidence Badge
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.file(
                            widget.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "${(widget.aiResult.confidence * 100).round()}% ${LanguageService.tr('Confidence')}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Health Score & Category Indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.aiResult.healthyScore >= 70
                          ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                          : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.aiResult.healthyScore >= 70
                            ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                            : Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.aiResult.healthyScore >= 70
                              ? Icons.health_and_safety_rounded
                              : Icons.info_outline_rounded,
                          color: widget.aiResult.healthyScore >= 70
                              ? const Color(0xFF22C55E)
                              : Colors.amber.shade800,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${LanguageService.tr('Health Score')}: ${widget.aiResult.healthyScore}/100",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                widget.aiResult.healthyScore >= 70
                                    ? LanguageService.tr("Nutritious and balanced meal choice")
                                    : LanguageService.tr("Moderate nutritional score"),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Food Name & Serving Size Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.tr("Identified Food"),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageService.tr("Serving Size"),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.aiResult.servingSize,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Macros Grid
                  Text(
                    LanguageService.tr("Nutritional Breakdown"),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr("Calories"),
                          value: "${widget.aiResult.calories.round()} kcal",
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr("Protein"),
                          value: "${widget.aiResult.protein.toStringAsFixed(1)} g",
                          icon: Icons.fitness_center_rounded,
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr("Carbs"),
                          value: "${widget.aiResult.carbs.toStringAsFixed(1)} g",
                          icon: Icons.grain_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr("Fat"),
                          value: "${widget.aiResult.fat.toStringAsFixed(1)} g",
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Action Button: Log Meal to Calorix
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final updatedResult = AIFoodResult(
                          foodName: _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()
                              : widget.aiResult.foodName,
                          calories: widget.aiResult.calories,
                          protein: widget.aiResult.protein,
                          carbs: widget.aiResult.carbs,
                          fat: widget.aiResult.fat,
                          fiber: widget.aiResult.fiber,
                          quantity: widget.aiResult.quantity,
                          confidence: widget.aiResult.confidence,
                          servingSize: widget.aiResult.servingSize,
                          healthyScore: widget.aiResult.healthyScore,
                        );

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMealScreen(
                              mealType: widget.mealType,
                              aiResult: updatedResult,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        LanguageService.tr("Log Meal to Calorix"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
