import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/goal_completion_service.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/health_calculator.dart';
import '../../../core/utils/responsive.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../calories/presentation/calories_detail_screen.dart';
import '../../health_calculator/presentation/health_calculator_screen.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/models/meal.dart';
import '../../meals/presentation/add_meal_screen.dart';
import '../../meals/presentation/meals_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../scan/presentation/scan_food_screen.dart';
import '../../steps/data/step_repository.dart';
import '../../steps/models/step_log.dart';
import '../../steps/presentation/steps_screen.dart';
import '../../water/data/water_repository.dart';
import '../../water/presentation/water_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserProfile profile;

  const DashboardScreen({super.key, required this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ProfileRepository profileRepository = ProfileRepository();
  final WaterRepository waterRepository = WaterRepository();
  final StepRepository stepRepository = StepRepository();

  int waterConsumed = 0;
  int waterGoal = 2500;
  StepLog? todaySteps;
  List<Meal> meals = [];

  bool loading = true;

  double totalCalories = 0;
  double totalProtein = 0;
  double totalCarbs = 0;
  double totalFat = 0;

  Meal? breakfastMeal;
  Meal? lunchMeal;
  Meal? dinnerMeal;

  @override
  void initState() {
    super.initState();
    MealRepository.instance.addListener(_onMealsChanged);
    waterRepository.addListener(_onWaterChanged);
    stepRepository.addListener(_onStepsChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    MealRepository.instance.removeListener(_onMealsChanged);
    waterRepository.removeListener(_onWaterChanged);
    stepRepository.removeListener(_onStepsChanged);
    super.dispose();
  }

  void _onMealsChanged() {
    _loadDashboardData();
  }

  void _onWaterChanged() {
    _loadWaterOnly();
  }

  void _onStepsChanged() {
    _loadStepsOnly();
  }

  Future<void> _loadWaterOnly() async {
    try {
      final waterData = await waterRepository.getTodayWater();
      if (!mounted) return;
      setState(() {
        waterConsumed = waterData.consumed;
        waterGoal = waterData.goal > 0 ? waterData.goal : 2500;
      });
    } catch (_) {}
  }

  Future<void> _loadStepsOnly() async {
    try {
      final stepsData = await stepRepository.getTodaySteps();
      if (!mounted) return;
      setState(() {
        todaySteps = stepsData;
      });
    } catch (_) {}
  }

  Future<void> _loadDashboardData() async {
    setState(() => loading = true);
    try {
      final todaysMeals = await MealRepository.instance.getTodaysMeals();
      final waterData = await waterRepository.getTodayWater();
      final stepsData = await stepRepository.getTodaySteps();

      double cal = 0, p = 0, c = 0, f = 0;
      Meal? b, l, d;

      for (final meal in todaysMeals) {
        cal += meal.calories;
        p += meal.protein;
        c += meal.carbs;
        f += meal.fat;

        final type = meal.mealType.toLowerCase();
        if (type == 'breakfast') b = meal;
        if (type == 'lunch') l = meal;
        if (type == 'dinner') d = meal;
      }

      if (!mounted) return;
      setState(() {
        meals = todaysMeals;
        totalCalories = cal;
        totalProtein = p;
        totalCarbs = c;
        totalFat = f;
        breakfastMeal = b;
        lunchMeal = l;
        dinnerMeal = d;
        waterConsumed = waterData.consumed;
        waterGoal = waterData.goal > 0 ? waterData.goal : 2500;
        todaySteps = stepsData;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _addWater(int amount) async {
    try {
      await waterRepository.addWater(amount);
    } catch (_) {}
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
    final primaryEmerald = isDark ? const Color(0xFF10B981) : const Color(0xFF047857);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final scaffoldBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F9F7);

    return StreamBuilder<UserProfile?>(
      stream: profileRepository.profileStream(),
      builder: (context, profileSnapshot) {
        final activeProfile = profileSnapshot.data ?? widget.profile;

        final bmr = HealthCalculator.calculateBMR(
          age: activeProfile.age > 0 ? activeProfile.age : 25,
          height: activeProfile.height > 0 ? activeProfile.height : 175.0,
          weight: activeProfile.currentWeight > 0 ? activeProfile.currentWeight : 70.0,
          gender: activeProfile.gender,
        );

        final dailyGoal = HealthCalculator.calculateDailyCalories(
          bmr: bmr,
          activity: activeProfile.activityLevel,
          goal: activeProfile.goal,
        );

        if (totalCalories >= dailyGoal && dailyGoal > 0) {
          GoalCompletionService.instance.checkCalorieGoal(
            consumedCalories: totalCalories,
            calorieGoal: dailyGoal.toDouble(),
          );
        }

        final remainingCalories = (dailyGoal - totalCalories).clamp(0, dailyGoal).toDouble();
        final calorieProgress = (totalCalories / dailyGoal).clamp(0.0, 1.0);

        final proteinGoal = (dailyGoal * 0.30 / 4);
        final carbsGoal = (dailyGoal * 0.45 / 4);
        final fatGoal = (dailyGoal * 0.25 / 9);

        final burnedCalories = todaySteps?.caloriesBurnedWithProfile(
              weightKg: activeProfile.currentWeight,
            ) ??
            0;

        final firstName = activeProfile.name.split(' ').first;

        return Scaffold(
          backgroundColor: scaffoldBgColor,
          body: SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    child: ResponsiveContentConstrained(
                      maxWidth: Responsive.maxDashboardWidth(context),
                      enableScroll: true,
                      child: _buildResponsiveBody(
                        activeProfile: activeProfile,
                        firstName: firstName,
                        isDark: isDark,
                        primaryEmerald: primaryEmerald,
                        cardBgColor: cardBgColor,
                        totalCalories: totalCalories,
                        remainingCalories: remainingCalories,
                        dailyGoal: dailyGoal,
                        burnedCalories: burnedCalories,
                        calorieProgress: calorieProgress,
                        totalProtein: totalProtein,
                        proteinGoal: proteinGoal,
                        totalCarbs: totalCarbs,
                        carbsGoal: carbsGoal,
                        totalFat: totalFat,
                        fatGoal: fatGoal,
                        waterConsumed: waterConsumed,
                        waterGoal: waterGoal,
                        todaySteps: todaySteps,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveBody({
    required UserProfile activeProfile,
    required String firstName,
    required bool isDark,
    required Color primaryEmerald,
    required Color cardBgColor,
    required double totalCalories,
    required double remainingCalories,
    required int dailyGoal,
    required int burnedCalories,
    required double calorieProgress,
    required double totalProtein,
    required double proteinGoal,
    required double totalCarbs,
    required double carbsGoal,
    required double totalFat,
    required double fatGoal,
    required int waterConsumed,
    required int waterGoal,
    required StepLog? todaySteps,
  }) {
    final isTablet = Responsive.isTabletOrDesktop(context);

    if (isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(activeProfile, firstName, isDark, primaryEmerald),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CaloriesDetailScreen(
                              userProfile: activeProfile,
                              dailyGoal: dailyGoal,
                            ),
                          ),
                        );
                      },
                      child: _buildCalorieCard(
                        totalCalories: totalCalories,
                        remainingCalories: remainingCalories,
                        dailyGoal: dailyGoal,
                        burnedCalories: burnedCalories,
                        calorieProgress: calorieProgress,
                        protein: totalProtein,
                        proteinGoal: proteinGoal,
                        carbs: totalCarbs,
                        carbsGoal: carbsGoal,
                        fat: totalFat,
                        fatGoal: fatGoal,
                        cardBgColor: cardBgColor,
                        primaryColor: primaryEmerald,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionGrid(cardBgColor, primaryEmerald, isDark),
                    const SizedBox(height: 24),
                    _buildTodaysMealsSection(cardBgColor, primaryEmerald, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildAiInsightBanner(remainingCalories, activeProfile, isDark),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WaterScreen(),
                          ),
                        );
                      },
                      child: _buildWaterCard(
                        consumed: waterConsumed,
                        goal: waterGoal,
                        cardBgColor: cardBgColor,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StepsScreen(),
                          ),
                        );
                      },
                      child: _buildStepsCard(
                        log: todaySteps ??
                            StepLog(
                              id: 'today',
                              userId: 'local',
                              date: '',
                              steps: 0,
                              goal: 10000,
                            ),
                        cardBgColor: cardBgColor,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(activeProfile, firstName, isDark, primaryEmerald),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaloriesDetailScreen(
                  userProfile: activeProfile,
                  dailyGoal: dailyGoal,
                ),
              ),
            );
          },
          child: _buildCalorieCard(
            totalCalories: totalCalories,
            remainingCalories: remainingCalories,
            dailyGoal: dailyGoal,
            burnedCalories: burnedCalories,
            calorieProgress: calorieProgress,
            protein: totalProtein,
            proteinGoal: proteinGoal,
            carbs: totalCarbs,
            carbsGoal: carbsGoal,
            fat: totalFat,
            fatGoal: fatGoal,
            cardBgColor: cardBgColor,
            primaryColor: primaryEmerald,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WaterScreen(),
              ),
            );
          },
          child: _buildWaterCard(
            consumed: waterConsumed,
            goal: waterGoal,
            cardBgColor: cardBgColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StepsScreen(),
              ),
            );
          },
          child: _buildStepsCard(
            log: todaySteps ??
                StepLog(
                  id: 'today',
                  userId: 'local',
                  date: '',
                  steps: 0,
                  goal: 10000,
                ),
            cardBgColor: cardBgColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
        _buildAiInsightBanner(remainingCalories, activeProfile, isDark),
        const SizedBox(height: 16),
        _buildQuickActionGrid(cardBgColor, primaryEmerald, isDark),
        const SizedBox(height: 24),
        _buildTodaysMealsSection(cardBgColor, primaryEmerald, isDark),
        const SizedBox(height: 30),
      ],
    );
  }

  // ===========================================================================
  // 1. HEADER ROW
  // ===========================================================================

  Widget _buildHeaderRow(
      UserProfile profile, String firstName, bool isDark, Color primaryColor) {
    final fullName = profile.name.trim().isNotEmpty ? profile.name.trim() : firstName;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LanguageService.tr("Welcome back,"),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                fullName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Row(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: NotificationService.instance.unreadCountNotifier,
              builder: (context, unreadCount, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 22),
                        color: isDark ? Colors.white70 : Colors.black87,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationCenterScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primaryColor.withAlpha((0.15 * 255).round()),
                  foregroundImage: profile.hasCustomAvatar
                      ? NetworkImage(profile.avatarUrl!) as ImageProvider
                      : AssetImage(profile.defaultAvatarAsset) as ImageProvider,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F9F7),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. CALORIE & MACRO CARD
  // ===========================================================================

  Widget _buildCalorieCard({
    required double totalCalories,
    required double remainingCalories,
    required int dailyGoal,
    required int burnedCalories,
    required double calorieProgress,
    required double protein,
    required double proteinGoal,
    required double carbs,
    required double carbsGoal,
    required double fat,
    required double fatGoal,
    required Color cardBgColor,
    required Color primaryColor,
    required bool isDark,
  }) {
    final formatter = NumberFormat("#,##0", "en_US");

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Calorie Progress Chart
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: calorieProgress,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatter.format(totalCalories.round()),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    LanguageService.tr("kcal eaten"),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Remaining Calories Header
          Text(
            "${formatter.format(remainingCalories.round())} kcal ${LanguageService.tr('remaining')}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${LanguageService.tr('of')} ${formatter.format(dailyGoal)} kcal ${LanguageService.tr('goal')}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),

          // Burned Calories Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF78350F).withValues(alpha: 0.4)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Text(
                  "$burnedCalories kcal ${LanguageService.tr('burned')}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Macro Progress Bars (Protein, Carbs, Fat)
          _macroProgressBar(
            label: LanguageService.tr("Protein"),
            consumed: protein,
            target: proteinGoal,
            color: const Color(0xFF2563EB), // Blue
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _macroProgressBar(
            label: LanguageService.tr("Carbs"),
            consumed: carbs,
            target: carbsGoal,
            color: const Color(0xFFB45309), // Amber/Brown
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _macroProgressBar(
            label: LanguageService.tr("Fat"),
            consumed: fat,
            target: fatGoal,
            color: const Color(0xFFDC2626), // Red
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _macroProgressBar({
    required String label,
    required double consumed,
    required double target,
    required Color color,
    required bool isDark,
  }) {
    final pct = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              "${consumed.round()}g / ${target.round()}g",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. WATER TRACKER CARD
  // ===========================================================================

  Widget _buildWaterCard({
    required int consumed,
    required int goal,
    required Color cardBgColor,
    required bool isDark,
  }) {
    final waterInLiters = (consumed / 1000).toStringAsFixed(1);
    final goalInLiters = (goal / 1000).toStringAsFixed(1);
    final progress = (consumed / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Color(0xFF0EA5E9),
                size: 22,
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${waterInLiters}L ",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                    TextSpan(
                      text: "/ ${goalInLiters}L",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Blue Water Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
            ),
          ),
          const SizedBox(height: 16),

          // Two Quick Water Buttons (+250ml & +500ml)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addWater(250),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "+250ml",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addWater(500),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "+500ml",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. STEPS TRACKER CARD
  // ===========================================================================

  Widget _buildStepsCard({
    required StepLog log,
    required Color cardBgColor,
    required bool isDark,
  }) {
    final formatter = NumberFormat("#,##0", "en_US");
    final pct = (log.completionPercentage * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_walk_rounded,
                    color: Color(0xFF22C55E),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService.tr("Today's Steps"),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$pct% ${LanguageService.tr('of goal')}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatter.format(log.steps),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "/ ${formatter.format(log.goal)} ${LanguageService.tr('steps')}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: log.completionPercentage,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        "${log.caloriesBurnedWithProfile(weightKg: widget.profile.currentWeight)} kcal",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 4),
                      Text(
                        "${log.distanceKmWithProfile(heightCm: widget.profile.height).toStringAsFixed(1)} km",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (log.syncStatus == 'pending')
                Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      LanguageService.tr("Waiting to sync"),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. AI INSIGHT BANNER
  // ===========================================================================

  Widget _buildAiInsightBanner(
      double remainingCalories, UserProfile profile, bool isDark) {
    final remainingText = remainingCalories.round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "✨",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                LanguageService.tr("Calorix AI Insight"),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            remainingText > 0
                ? "${LanguageService.tr("You're")} $remainingText ${LanguageService.tr("kcal below your target. Your protein is on track, but adding a protein-rich dinner could help you reach your goal.")}"
                : LanguageService.tr("Great work! You've met your daily calorie target. Keep staying hydrated and get good rest tonight."),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. QUICK ACTION GRID (2x2)
  // ===========================================================================

  Widget _buildQuickActionGrid(
      Color cardBgColor, Color primaryColor, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.camera_alt_outlined,
                label: LanguageService.tr("Scan Food"),
                isFilled: false,
                cardBgColor: cardBgColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanFoodScreen(mealType: "Lunch"),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _actionButton(
                icon: Icons.add_rounded,
                label: LanguageService.tr("Add Meal"),
                isFilled: true,
                cardBgColor: cardBgColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddMealScreen(mealType: "Breakfast"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.water_drop_outlined,
                label: LanguageService.tr("Add Water"),
                isFilled: false,
                cardBgColor: cardBgColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WaterScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _actionButton(
                icon: Icons.calculate_outlined,
                label: LanguageService.tr("Calculator"),
                isFilled: false,
                cardBgColor: cardBgColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HealthCalculatorScreen(userProfile: widget.profile),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool isFilled,
    required Color cardBgColor,
    required Color primaryColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isFilled ? primaryColor : cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFilled
                ? primaryColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          boxShadow: [
            BoxShadow(
              color: isFilled
                  ? primaryColor.withValues(alpha: 0.3)
                  : (isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.02)),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isFilled
                  ? Colors.white
                  : (isDark ? Colors.white : primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isFilled
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. TODAY'S MEALS SECTION
  // ===========================================================================

  Widget _buildTodaysMealsSection(
      Color cardBgColor, Color primaryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LanguageService.tr("Today's Meals"),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MealsScreen()),
                );
              },
              child: Text(
                LanguageService.tr("See All"),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Breakfast Card
        _buildMealCardItem(
          type: "Breakfast",
          meal: breakfastMeal,
          icon: Icons.free_breakfast_rounded,
          cardBgColor: cardBgColor,
          primaryColor: primaryColor,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Lunch Card
        _buildMealCardItem(
          type: "Lunch",
          meal: lunchMeal,
          icon: Icons.lunch_dining_rounded,
          cardBgColor: cardBgColor,
          primaryColor: primaryColor,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Dinner Card
        _buildMealCardItem(
          type: "Dinner",
          meal: dinnerMeal,
          icon: Icons.dinner_dining_rounded,
          cardBgColor: cardBgColor,
          primaryColor: primaryColor,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildMealCardItem({
    required String type,
    required Meal? meal,
    required IconData icon,
    required Color cardBgColor,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isLogged = meal != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMealScreen(mealType: type, meal: isLogged ? meal : null),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLogged
                ? (isDark ? Colors.white12 : Colors.grey.shade200)
                : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr(type),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLogged
                        ? "${meal.calories.round()} kcal • ${meal.protein.round()}g ${LanguageService.tr('protein')}"
                        : LanguageService.tr("Not logged yet"),
                    style: TextStyle(
                      fontSize: 13,
                      color: isLogged
                          ? primaryColor
                          : isDark
                              ? Colors.white54
                              : Colors.grey.shade500,
                      fontWeight: isLogged ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: primaryColor,
                size: 26,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMealScreen(mealType: type),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
