import 'package:ai_calorie_counter/features/home/presentation/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/utils/responsive.dart';
import '../data/profile_repository.dart';
import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final targetWeightController = TextEditingController();

  final ProfileRepository profileRepository = ProfileRepository();

  bool _isLoading = false;
  Future<void> _saveProfile() async {
    if (ageController.text.isEmpty ||
        heightController.text.isEmpty ||
        weightController.text.isEmpty ||
        targetWeightController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final profile = UserProfile(
        uid: user.uid,
        name: user.displayName ?? "",
        email: user.email ?? "",
        age: int.parse(ageController.text),
        height: double.parse(heightController.text),
        currentWeight: double.parse(weightController.text),
        targetWeight: double.parse(targetWeightController.text),
        gender: gender,
        activityLevel: activity,
        goal: goal,
      );

      await profileRepository.saveProfile(profile);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    targetWeightController.dispose();
    super.dispose();
  }

  String gender = "Male";
  String goal = "Lose Weight";
  String activity = "Moderately Active";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
        centerTitle: true,
      ),
      body: ResponsiveContentConstrained(
        maxWidth: Responsive.maxFormWidth(context),
        enableScroll: true,
        child: Column(
          children: [
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calorix',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      'Snap. Track. Thrive.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 25),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Age",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Height (cm)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Current Weight (kg)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: targetWeightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Target Weight (kg)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "Male", child: Text("Male")),
                DropdownMenuItem(value: "Female", child: Text("Female")),
              ],
              onChanged: (value) {
                setState(() {
                  gender = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: activity,
              decoration: const InputDecoration(
                labelText: "Activity Level",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "Sedentary", child: Text("Sedentary")),
                DropdownMenuItem(
                  value: "Lightly Active",
                  child: Text("Lightly Active"),
                ),
                DropdownMenuItem(
                  value: "Moderately Active",
                  child: Text("Moderately Active"),
                ),
                DropdownMenuItem(
                  value: "Very Active",
                  child: Text("Very Active"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  activity = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: goal,
              decoration: const InputDecoration(
                labelText: "Goal",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Lose Weight",
                  child: Text("Lose Weight"),
                ),
                DropdownMenuItem(
                  value: "Maintain Weight",
                  child: Text("Maintain Weight"),
                ),
                DropdownMenuItem(
                  value: "Gain Weight",
                  child: Text("Gain Weight"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  goal = value!;
                });
              },
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                ),

                // Save to Firestore in next step
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Continue", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
