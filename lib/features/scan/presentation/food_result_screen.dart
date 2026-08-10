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
  late final TextEditingController _nameController;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.aiResult.foodName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndLogMeal() async {
    if (_isConfirming) return;

    final foodName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.aiResult.foodName;

    final shouldLog = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final confidencePercent = (widget.aiResult.confidence * 100).round();

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(LanguageService.tr('Confirm Meal')),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr(
                    'Please verify the AI estimate before adding this meal to your daily log.',
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _buildConfirmationRow(
                  dialogContext,
                  LanguageService.tr('Food'),
                  foodName,
                ),
                _buildConfirmationRow(
                  dialogContext,
                  LanguageService.tr('Calories'),
                  '${widget.aiResult.calories.round()} kcal',
                ),
                _buildConfirmationRow(
                  dialogContext,
                  LanguageService.tr('Protein'),
                  '${widget.aiResult.protein.toStringAsFixed(1)} g',
                ),
                _buildConfirmationRow(
                  dialogContext,
                  LanguageService.tr('Carbs'),
                  '${widget.aiResult.carbs.toStringAsFixed(1)} g',
                ),
                _buildConfirmationRow(
                  dialogContext,
                  LanguageService.tr('Fat'),
                  '${widget.aiResult.fat.toStringAsFixed(1)} g',
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: confidencePercent >= 70
                        ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                        : Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        confidencePercent >= 70
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        size: 20,
                        color: confidencePercent >= 70
                            ? const Color(0xFF16A34A)
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${LanguageService.tr('AI confidence')}: $confidencePercent%. ${LanguageService.tr('Nutrition values are estimates and may vary with ingredients and portion size.')}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(LanguageService.tr('Review Again')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(LanguageService.tr('Confirm & Continue')),
            ),
          ],
        );
      },
    );

    if (shouldLog != true || !mounted) return;

    setState(() => _isConfirming = true);

    try {
      final updatedResult = AIFoodResult(
        foodName: foodName,
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

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddMealScreen(
            mealType: widget.mealType,
            aiResult: updatedResult,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  Widget _buildConfirmationRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark
            ? const Color(0xFF10B981)
            : const Color(0xFF047857);
        final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final confidencePercent = (widget.aiResult.confidence * 100).round();

        return Scaffold(
          appBar: AppBar(
            title: Text(LanguageService.tr('Food Analysis Results')),
            centerTitle: true,
          ),
          body: SafeArea(
            child: ResponsiveContentConstrained(
              maxWidth: Responsive.maxFormWidth(context),
              enableScroll: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                confidencePercent >= 70
                                    ? Icons.verified_rounded
                                    : Icons.warning_amber_rounded,
                                color: confidencePercent >= 70
                                    ? const Color(0xFF22C55E)
                                    : Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$confidencePercent% ${LanguageService.tr('Confidence')}',
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            LanguageService.tr(
                              'AI results are estimates. Check the food, portion size and nutrition values before logging your meal.',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                                '${LanguageService.tr('Health Score')}: ${widget.aiResult.healthyScore}/100',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                widget.aiResult.healthyScore >= 70
                                    ? LanguageService.tr(
                                        'Nutritious and balanced meal choice',
                                      )
                                    : LanguageService.tr(
                                        'Moderate nutritional score',
                                      ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.tr('Identified Food'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                    LanguageService.tr('Serving Size'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.grey.shade600,
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
                  Text(
                    LanguageService.tr('Nutritional Breakdown'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr('Calories'),
                          value: '${widget.aiResult.calories.round()} kcal',
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr('Protein'),
                          value: '${widget.aiResult.protein.toStringAsFixed(1)} g',
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
                          title: LanguageService.tr('Carbs'),
                          value: '${widget.aiResult.carbs.toStringAsFixed(1)} g',
                          icon: Icons.grain_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroStatCard(
                          title: LanguageService.tr('Fat'),
                          value: '${widget.aiResult.fat.toStringAsFixed(1)} g',
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isConfirming ? null : _confirmAndLogMeal,
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_task_rounded),
                      label: Text(
                        _isConfirming
                            ? LanguageService.tr('Opening Meal Editor...')
                            : LanguageService.tr('Review & Log Meal'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
          color: isDark
              ? Colors.white12
              : Colors.black.withValues(alpha: 0.05),
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
