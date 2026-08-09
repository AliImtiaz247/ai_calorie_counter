import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/health_calculator.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../../weight/data/weight_repository.dart';

class HealthCalculatorScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const HealthCalculatorScreen({super.key, this.userProfile});

  @override
  State<HealthCalculatorScreen> createState() => _HealthCalculatorScreenState();
}

class _HealthCalculatorScreenState extends State<HealthCalculatorScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;

  String _gender = "Male";
  String _activityLevel = "Moderately Active";
  String _goal = "Maintain Weight";
  bool _isSaving = false;

  final List<String> _genderOptions = ["Male", "Female", "Other"];
  final List<String> _activityOptions = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
  ];
  final List<String> _goalOptions = [
    "Lose Weight",
    "Maintain Weight",
    "Gain Weight",
  ];

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _ageController = TextEditingController();

    final profile = ProfileRepository().cachedProfile ?? widget.userProfile;
    if (profile != null) {
      _applyProfileToFields(profile);
    } else {
      _heightController.text = "175";
      _weightController.text = "70.0";
      _ageController.text = "25";
    }
  }

  void _applyProfileToFields(UserProfile profile) {
    _heightController.text =
        profile.height > 0 ? profile.height.toStringAsFixed(0) : "175";
    _weightController.text = profile.currentWeight > 0
        ? profile.currentWeight.toStringAsFixed(1)
        : "70.0";
    _ageController.text =
        profile.age > 0 ? profile.age.toString() : "25";

    final g = profile.gender.trim().toLowerCase();
    if (g.contains('female')) {
      _gender = "Female";
    } else if (g.contains('other')) {
      _gender = "Other";
    } else if (g.contains('male')) {
      _gender = "Male";
    }

    final act = profile.activityLevel.trim().toLowerCase();
    if (act.contains('sedentary')) {
      _activityLevel = "Sedentary";
    } else if (act.contains('light')) {
      _activityLevel = "Lightly Active";
    } else if (act.contains('very') || act.contains('extra')) {
      _activityLevel = "Very Active";
    } else if (act.contains('mod')) {
      _activityLevel = "Moderately Active";
    }

    final gl = profile.goal.trim().toLowerCase();
    if (gl.contains('lose')) {
      _goal = "Lose Weight";
    } else if (gl.contains('gain')) {
      _goal = "Gain Weight";
    } else if (gl.contains('maintain')) {
      _goal = "Maintain Weight";
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final parsedHeight =
        double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 175.0;
    final parsedWeight =
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 70.0;
    final parsedAge = int.tryParse(_ageController.text) ?? 25;

    final height = parsedHeight > 0 ? parsedHeight : 175.0;
    final weight = parsedWeight > 0 ? parsedWeight : 70.0;
    final age = parsedAge > 0 ? parsedAge : 25;

    final currentGender =
        _genderOptions.contains(_gender) ? _gender : _genderOptions[0];
    final currentActivity = _activityOptions.contains(_activityLevel)
        ? _activityLevel
        : _activityOptions[2];
    final currentGoal =
        _goalOptions.contains(_goal) ? _goal : _goalOptions[1];

    final bmi = HealthCalculator.calculateBMI(weight: weight, height: height);
    final bmiCat = HealthCalculator.bmiCategory(bmi);
    final bmiColor = HealthCalculator.bmiColor(bmi);
    final idealRange = HealthCalculator.idealWeightRange(height);

    final bmr = HealthCalculator.calculateBMR(
      age: age,
      height: height,
      weight: weight,
      gender: currentGender,
    );

    final tdee = HealthCalculator.calculateTDEE(
      bmr: bmr,
      activity: currentActivity,
    );

    final targetCalories = HealthCalculator.calculateDailyCalories(
      bmr: bmr,
      activity: currentActivity,
      goal: currentGoal,
    );

    final macros = HealthCalculator.calculateMacros(targetCalories);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.tr('Health Calculator'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: ResponsiveContentConstrained(
        maxWidth: Responsive.maxFormWidth(context),
        enableScroll: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subtitle
            Text(
              LanguageService.tr("Calculate your BMI, BMR, TDEE and customized daily nutrition targets."),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // Input Card
            _buildInputSection(isDark, currentGender, currentActivity, currentGoal),
            const SizedBox(height: 24),

            // Results Section Title
            Text(
              LanguageService.tr("Your Calculation Results"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            // 1. BMI Card
            _buildBmiCard(bmi, bmiCat, bmiColor, idealRange, isDark),
            const SizedBox(height: 16),

            // 2. BMR & TDEE Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "BMR",
                    value: "${bmr.round()}",
                    unit: "kcal / day",
                    subtitle: LanguageService.tr("Basal Metabolic Rate"),
                    icon: Icons.hotel_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: "TDEE",
                    value: "${tdee.round()}",
                    unit: "kcal / day",
                    subtitle: LanguageService.tr("Maintenance Energy"),
                    icon: Icons.bolt_rounded,
                    color: Colors.amber.shade800,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Goal Calorie Target & Macro Breakdown Card
            _buildNutritionGoalCard(targetCalories, macros, isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(
    bool isDark,
    String currentGender,
    String currentActivity,
    String currentGoal,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LanguageService.tr("Personal Data"),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Height, Weight, Age Row
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: LanguageService.tr("Height (cm)"),
                  controller: _heightController,
                  icon: Icons.height_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: LanguageService.tr("Weight (kg)"),
                  controller: _weightController,
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: LanguageService.tr("Age (yrs)"),
                  controller: _ageController,
                  icon: Icons.cake_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gender Toggle
          Text(
            LanguageService.tr("Gender"),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: _genderOptions.map((g) {
              IconData icon;
              if (g == "Male") {
                icon = Icons.male;
              } else if (g == "Female") {
                icon = Icons.female;
              } else {
                icon = Icons.person_outline_rounded;
              }
              return ButtonSegment<String>(
                value: g,
                label: Text(LanguageService.tr(g), style: const TextStyle(fontSize: 12)),
                icon: Icon(icon, size: 18),
              );
            }).toList(),
            selected: {currentGender},
            onSelectionChanged: (set) {
              setState(() => _gender = set.first);
            },
          ),
          const SizedBox(height: 16),

          // Activity Level Dropdown
          Text(
            LanguageService.tr("Activity Level"),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: currentActivity,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: _activityOptions.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(LanguageService.tr(opt)));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _activityLevel = val);
            },
          ),
          const SizedBox(height: 16),

          // Goal Dropdown
          Text(
            LanguageService.tr("Fitness Goal"),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: currentGoal,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: _goalOptions.map((g) {
              return DropdownMenuItem(value: g, child: Text(LanguageService.tr(g)));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _goal = val);
            },
          ),
          const SizedBox(height: 20),

          // Save & Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePersonalDataToProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                LanguageService.tr("Save & Apply to App Profile"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePersonalDataToProfile() async {
    final parsedHeight =
        double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 175.0;
    final parsedWeight =
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 70.0;
    final parsedAge = int.tryParse(_ageController.text) ?? 25;

    final height = parsedHeight > 0 ? parsedHeight : 175.0;
    final weight = parsedWeight > 0 ? parsedWeight : 70.0;
    final age = parsedAge > 0 ? parsedAge : 25;

    setState(() {
      _isSaving = true;
    });

    try {
      await ProfileRepository().updateHealthMetrics(
        height: height,
        currentWeight: weight,
        age: age,
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
      );

      await WeightRepository().addWeightLog(
        weight,
        note: "Updated via Health Calculator",
      );

      final updatedProfile = ProfileRepository().cachedProfile;
      if (updatedProfile != null) {
        _applyProfileToFields(updatedProfile);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal data updated successfully across the app!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update personal data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildBmiCard(
    double bmi,
    String category,
    Color categoryColor,
    Map<String, double> idealRange,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.speed_rounded, color: categoryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService.tr("Body Mass Index (BMI)"),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            LanguageService.tr("Height-to-weight ratio"),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "kg/m²",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Gauge Bar
          _buildBmiScaleBar(bmi),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${LanguageService.tr('Healthy Range')}: ${idealRange['min']!.toStringAsFixed(1)} - ${idealRange['max']!.toStringAsFixed(1)} kg",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBmiScaleBar(double bmi) {
    // Clamp progress between 10.0 and 40.0 for gauge display
    final minVal = 12.0;
    final maxVal = 38.0;
    final normalized = ((bmi - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final pointerPos = normalized * barWidth;

        return Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 185,
                        child: Container(height: 10, color: Colors.amber),
                      ),
                      Expanded(
                        flex: 65,
                        child: Container(height: 10, color: const Color(0xFF22C55E)),
                      ),
                      Expanded(
                        flex: 50,
                        child: Container(height: 10, color: Colors.orange),
                      ),
                      Expanded(
                        flex: 100,
                        child: Container(height: 10, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: (pointerPos - 6).clamp(0.0, barWidth - 12),
                  top: -3,
                  child: Container(
                    width: 12,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("<18.5", style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text("18.5-24.9", style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text("25-29.9", style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text("30+", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "kcal",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionGoalCard(
    int calories,
    MacroBreakdown macros,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr("Target Daily Calories"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "${LanguageService.tr("Goal")}: $_goal",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$calories",
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "kcal / day",
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            LanguageService.tr("Recommended Macros Breakdown"),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMacroPill(
                  label: LanguageService.tr("Protein"),
                  grams: "${macros.proteinGrams}g",
                  pct: "30%",
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroPill(
                  label: LanguageService.tr("Carbs"),
                  grams: "${macros.carbsGrams}g",
                  pct: "40%",
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroPill(
                  label: LanguageService.tr("Fats"),
                  grams: "${macros.fatGrams}g",
                  pct: "30%",
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPill({
    required String label,
    required String grams,
    required String pct,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grams,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pct,
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
