import 'package:ai_calorie_counter/core/widgets/calorie_progress_card.dart';
import 'package:ai_calorie_counter/core/widgets/date_selector.dart';
import 'package:ai_calorie_counter/features/meals/presentation/add_meal_screen.dart';
import 'package:ai_calorie_counter/features/scan/presentation/scan_food_screen.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/health_calculator.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../data/meal_repository.dart';
import '../models/meal.dart';
import 'widgets/meal_tile.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final MealRepository repository = MealRepository.instance;
  final ProfileRepository profileRepository = ProfileRepository();

  bool loading = true;

  List<Meal> meals = [];

  UserProfile? profile;

  int dailyCalorieGoal = 2000;

  DateTime selectedDate = DateTime.now();

  double breakfastCalories = 0;
  double lunchCalories = 0;
  double dinnerCalories = 0;
  double snacksCalories = 0;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onMealsChanged);
    loadMeals();
  }

  @override
  void dispose() {
    repository.removeListener(_onMealsChanged);
    super.dispose();
  }

  void _onMealsChanged() {
    loadMeals();
  }

  Future<void> loadMeals() async {
    meals = await repository.getMealsByDate(selectedDate);
    profile = await profileRepository.getProfile();

    breakfastCalories = 0;
    lunchCalories = 0;
    dinnerCalories = 0;
    snacksCalories = 0;

    for (final meal in meals) {
      switch (meal.mealType) {
        case "Breakfast":
          breakfastCalories += meal.calories;
          break;

        case "Lunch":
          lunchCalories += meal.calories;
          break;

        case "Dinner":
          dinnerCalories += meal.calories;
          break;

        case "Snacks":
          snacksCalories += meal.calories;
          break;
      }
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  List<Meal> mealsForType(String mealType) {
    return meals.where((e) => e.mealType == mealType).toList();
  }

  Future<void> previousDay() async {
    selectedDate = selectedDate.subtract(const Duration(days: 1));

    setState(() {});

    await loadMeals();
  }

  Future<void> nextDay() async {
    final today = DateTime.now();

    final todayOnly = DateTime(today.year, today.month, today.day);

    if (selectedDate.isBefore(todayOnly)) {
      selectedDate = selectedDate.add(const Duration(days: 1));

      setState(() {});

      await loadMeals();
    }
  }

  String getMealTitle() {
    final today = DateTime.now();

    final todayDate = DateTime(today.year, today.month, today.day);

    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final difference = todayDate.difference(selected).inDays;

    if (difference == 0) {
      return LanguageService.tr("Today's Meals");
    }

    if (difference == 1) {
      return LanguageService.tr("Yesterday's Meals");
    }

    return "${selected.day} ${_month(selected.month)} ${selected.year}";
  }

  String _month(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return months[month - 1];
  }

  Future<void> _openAddMeal(String mealType) async {
    final refreshed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMealScreen(mealType: mealType)),
    );

    if (refreshed == true) {
      await loadMeals();
    }
  }

  void _openAiScan(String mealType) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanFoodScreen(mealType: mealType)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final totalCalories = meals.fold<double>(
      0,
      (sum, meal) => sum + meal.calories,
    );

    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      totalProtein += meal.protein;
      totalCarbs += meal.carbs;
      totalFat += meal.fat;
    }

    return StreamBuilder<UserProfile?>(
      stream: profileRepository.profileStream(),
      builder: (context, profileSnapshot) {
        final activeProfile = profileSnapshot.data ?? profile;

        int dynamicDailyGoal = 2000;
        if (activeProfile != null) {
          final bmr = HealthCalculator.calculateBMR(
            age: activeProfile.age > 0 ? activeProfile.age : 25,
            height: activeProfile.height > 0 ? activeProfile.height : 175.0,
            weight: activeProfile.currentWeight > 0
                ? activeProfile.currentWeight
                : 70.0,
            gender: activeProfile.gender,
          );

          dynamicDailyGoal = HealthCalculator.calculateDailyCalories(
            bmr: bmr,
            activity: activeProfile.activityLevel,
            goal: activeProfile.goal,
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: loadMeals,
              child: ResponsiveContentConstrained(
                maxWidth: Responsive.maxDashboardWidth(context),
                enableScroll: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CalorieProgressCard(
                      consumedCalories: totalCalories,
                      dailyGoal: dynamicDailyGoal.toDouble(),
                      protein: totalProtein,
                      proteinGoal: (dynamicDailyGoal * 0.30 / 4),
                      carbs: totalCarbs,
                      carbsGoal: (dynamicDailyGoal * 0.45 / 4),
                      fat: totalFat,
                      fatGoal: (dynamicDailyGoal * 0.25 / 9),
                    ),

                    const SizedBox(height: 24),

                    DateSelector(
                      selectedDate: selectedDate,
                      onPrevious: previousDay,
                      onNext: nextDay,
                    ),

                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      getMealTitle(),
                      key: ValueKey(selectedDate),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                _mealCard(
                  title: LanguageService.tr("Breakfast"),
                  subtitle: LanguageService.tr("Start your morning right"),
                  calories: breakfastCalories,
                  icon: Icons.free_breakfast_rounded,
                  color: Colors.orange,
                  onAdd: () => _openAddMeal("Breakfast"),
                  onScan: () => _openAiScan("Breakfast"),
                ),

                const SizedBox(height: 18),

                _mealCard(
                  title: LanguageService.tr("Lunch"),
                  subtitle: LanguageService.tr("Recharge your energy"),
                  calories: lunchCalories,
                  icon: Icons.lunch_dining_rounded,
                  color: Colors.green,
                  onAdd: () => _openAddMeal("Lunch"),
                  onScan: () => _openAiScan("Lunch"),
                ),

                const SizedBox(height: 18),
                _mealCard(
                  title: LanguageService.tr("Dinner"),
                  subtitle: LanguageService.tr("Finish the day healthy"),
                  calories: dinnerCalories,
                  icon: Icons.dinner_dining_rounded,
                  color: Colors.deepPurple,
                  onAdd: () => _openAddMeal("Dinner"),
                  onScan: () => _openAiScan("Dinner"),
                ),

                const SizedBox(height: 18),

                _mealCard(
                  title: LanguageService.tr("Snacks"),
                  subtitle: LanguageService.tr("Small bites & drinks"),
                  calories: snacksCalories,
                  icon: Icons.fastfood_rounded,
                  color: Colors.redAccent,
                  onAdd: () => _openAddMeal("Snacks"),
                  onScan: () => _openAiScan("Snacks"),
                ),

                const SizedBox(height: 30),

                if (meals.isNotEmpty) ...[
                  Text(
                    LanguageService.tr("Today's Entries"),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  ...meals.map(
                    (meal) => MealTile(
                      meal: meal,
                      onEdit: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMealScreen(
                              mealType: meal.mealType,
                              meal: meal,
                            ),
                          ),
                        );

                        if (updated == true) {
                          await loadMeals();
                        }
                      },
                      onDelete: () async {
                        await repository.deleteMeal(meal.id);
                        await loadMeals();
                      },
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 40),

                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 70,
                          color: Colors.grey.shade400,
                        ),

                        const SizedBox(height: 18),

                        Text(
                          LanguageService.tr("No meals added yet"),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          LanguageService.tr("Start by adding your first meal\nor scan it using AI."),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _mealCard({
    required String title,
    required String subtitle,
    required double calories,
    required IconData icon,
    required Color color,
    required VoidCallback onAdd,
    required VoidCallback onScan,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 34),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      "${calories.toStringAsFixed(0)} kcal",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            children: [
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(LanguageService.tr("Add")),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(90, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: Text(LanguageService.tr("AI")),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(90, 42),
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
