import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/ai_food_result.dart';
import '../../../core/models/scan_usage.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/food_ai_service.dart';
import '../../../core/services/language_service.dart';
import 'food_result_screen.dart';

class ScanFoodScreen extends StatefulWidget {
  final String mealType;

  const ScanFoodScreen({super.key, required this.mealType});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen> {
  final picker = ImagePicker();
  final FoodAIService foodAIService = FoodAIService();

  File? image;
  bool loading = false;

  ScanUsage? _scanUsage;
  bool _loadingUsage = true;

  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialNetwork();
    _fetchScanUsage();
  }

  Future<void> _fetchScanUsage() async {
    if (!mounted) return;
    setState(() {
      _loadingUsage = true;
    });

    try {
      final usage = await foodAIService.getScanUsage();
      if (mounted) {
        setState(() {
          _scanUsage = usage;
          _loadingUsage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingUsage = false;
        });
      }
    }
  }

  Future<void> _checkInitialNetwork() async {
    final hasNet = await ConnectivityService.hasInternetConnection();
    if (mounted) {
      setState(() {
        _isOffline = !hasNet;
      });
    }
  }

  Future<void> pickImage() async {
    if (loading) return;
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      image = File(picked.path);
    });
  }

  Future<void> pickImageFromGallery() async {
    if (loading) return;
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      image = File(picked.path);
    });
  }

  Future<void> analyzeFood() async {
    if (image == null || loading) return;

    if (_scanUsage != null && _scanUsage!.remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            'Daily scan limit reached. Scans will reset at 12:00 AM.',
          )),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final hasNetwork = await ConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      if (!mounted) return;
      setState(() => _isOffline = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            'Internet connection is required to analyze food with AI. Please connect to the internet and try again.',
          )),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => loading = true);

    try {
      final result = await foodAIService
          .analyzeFood(image!)
          .timeout(const Duration(seconds: 95));

      if (!mounted) return;

      final aiResult = AIFoodResult.fromJson(result);

      if (aiResult.scanUsage != null) {
        setState(() {
          _scanUsage = aiResult.scanUsage;
        });
      } else {
        await _fetchScanUsage();
      }

      await precacheImage(FileImage(image!), context);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodResultScreen(
            image: image!,
            aiResult: aiResult,
            mealType: widget.mealType,
          ),
        ),
      );

      await _fetchScanUsage();
    } on ScanLimitException catch (limitErr) {
      if (!mounted) return;
      setState(() => _scanUsage = limitErr.scanUsage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(limitErr.message)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } on ScanInProgressException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(err.message)),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } on AiQuotaTemporarilyExhaustedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            'Calorix AI is temporarily unavailable. Your daily scan was not used. Please try again later.',
          )),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            err.code == 'AI_REQUEST_TIMEOUT'
                ? 'AI analysis timed out. Please try again.'
                : err.message,
          )),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            'Unable to connect to the server. Please check your internet connection.',
          )),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr(
            'AI analysis timed out. Please try again.',
          )),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${LanguageService.tr('Analysis failed')}: ${e.toString().replaceAll('Exception:', '').trim()}",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.tr('AI Food Scanner')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageService.tr('Refresh Scan Counter'),
            onPressed: loading ? null : _fetchScanUsage,
          ),
        ],
      ),
      body: SafeArea(
        child: _isOffline
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black38
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFEF4444),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          LanguageService.tr('Internet Connection Required'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          LanguageService.tr(
                            'AI food scanning requires an internet connection. Connect to the internet and try again.',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final hasNet = await ConnectivityService.hasInternetConnection();
                              if (!mounted) return;
                              setState(() {
                                _isOffline = !hasNet;
                              });
                              if (!hasNet) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(LanguageService.tr(
                                      'Still offline. Please check connection.',
                                    )),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } else {
                                _fetchScanUsage();
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              LanguageService.tr('Try Again'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      children: [
                        _buildScanUsageBadge(context),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageService.tr('Scan your meal'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                LanguageService.tr(
                                  'Use the AI scanner to identify calories, macros and portion size. Capture the meal from above and make sure it is well lit.',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _buildPreviewCard(context)),
                              const SizedBox(height: 14),
                              _buildActionPanel(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildScanUsageBadge(BuildContext context) {
    if (_loadingUsage && _scanUsage == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              LanguageService.tr('Checking daily scan limit...'),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final usage = _scanUsage ?? ScanUsage(limit: 4, used: 0, remaining: 4);
    final isLimitReached = usage.remaining <= 0;

    final primaryColor = isLimitReached
        ? const Color(0xFFEF4444)
        : const Color(0xFF22C55E);
    final bgColor = isLimitReached
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : const Color(0xFF22C55E).withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLimitReached
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isLimitReached ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLimitReached ? Icons.block_rounded : Icons.bolt_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isLimitReached
                        ? LanguageService.tr('Daily Limit Reached')
                        : LanguageService.tr('AI Food Scans'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isLimitReached
                          ? const Color(0xFFEF4444)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${usage.remaining}/${usage.limit} ${LanguageService.tr('remaining today')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (usage.used / usage.limit).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          if (isLimitReached) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    LanguageService.tr('Daily scan limit reached. Resets at 12:00 AM local time.'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Text(
              LanguageService.tr('Food Preview'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: image == null
                      ? Container(
                          key: const ValueKey('empty'),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              LanguageService.tr('No image selected yet. Tap the camera button to capture your meal.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ),
                        )
                      : Image.file(
                          image!,
                          key: const ValueKey('preview'),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    final isLimitReached = (_scanUsage?.remaining ?? 4) <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(LanguageService.tr('Take Picture')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: loading ? null : pickImage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: Text(LanguageService.tr('Gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: loading ? null : pickImageFromGallery,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: loading || image == null || isLimitReached ? null : analyzeFood,
            style: ElevatedButton.styleFrom(
              backgroundColor: loading || image == null || isLimitReached
                  ? Colors.grey.shade400
                  : const Color(0xFF0B3366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Text(
                    isLimitReached
                        ? LanguageService.tr('Daily Limit Reached (4/4)')
                        : LanguageService.tr('Analyze Food'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        if (isLimitReached) ...[
          const SizedBox(height: 6),
          Text(
            LanguageService.tr('Scans reset automatically at 12:00 AM local time.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
