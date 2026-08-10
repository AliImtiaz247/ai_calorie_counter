import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/ai_food_result.dart';
import '../../../core/models/scan_usage.dart';
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
    setState(() => _loadingUsage = true);

    try {
      final usage = await foodAIService.getScanUsage();
      if (!mounted) return;
      setState(() {
        _scanUsage = usage;
        _loadingUsage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUsage = false);
    }
  }

  Future<void> _checkInitialNetwork() async {
    final hasNet = await ConnectivityService.hasInternetConnection();
    if (!mounted) return;
    setState(() => _isOffline = !hasNet);
  }

  Future<void> pickImage() async {
    if (loading) return;

    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;
    setState(() => image = File(picked.path));
  }

  Future<void> pickImageFromGallery() async {
    if (loading) return;

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;
    setState(() => image = File(picked.path));
  }

  Future<void> analyzeFood() async {
    if (image == null || loading) return;

    if (_scanUsage != null && _scanUsage!.remaining <= 0) {
      _showMessage(
        LanguageService.tr(
          'Daily scan limit reached. Scans will reset at 12:00 AM.',
        ),
        error: true,
      );
      return;
    }

    final hasNetwork = await ConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      if (!mounted) return;
      setState(() => _isOffline = true);
      _showMessage(
        LanguageService.tr(
          'Internet connection is required to analyze food with AI. Please connect to the internet and try again.',
        ),
        error: true,
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
        setState(() => _scanUsage = aiResult.scanUsage);
      } else {
        await _fetchScanUsage();
      }

      if (!mounted) return;

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
      _showMessage(LanguageService.tr(limitErr.message), error: true);
    } on ScanInProgressException catch (err) {
      if (!mounted) return;
      _showMessage(
        LanguageService.tr(err.message),
        error: true,
        duration: const Duration(seconds: 3),
      );
    } on AiQuotaTemporarilyExhaustedException catch (err) {
      if (!mounted) return;
      // This is Google's/Gemini's quota, not the user's 4-scan limit.
      // Do not decrement or modify the user's local scan counter here.
      _showMessage(
        LanguageService.tr(
          'Calorix AI is temporarily unavailable. Your daily scan was not used. Please try again later.',
        ),
        error: true,
        duration: const Duration(seconds: 5),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      final message = err.code == 'AI_REQUEST_TIMEOUT'
          ? 'AI analysis timed out. Please try again.'
          : err.message;
      _showMessage(LanguageService.tr(message), error: true);
    } on SocketException {
      if (!mounted) return;
      _showMessage(
        LanguageService.tr('Unable to connect to the server. Please check your internet connection.'),
        error: true,
      );
    } on TimeoutException {
      if (!mounted) return;
      _showMessage(
        LanguageService.tr('AI analysis timed out. Please try again.'),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        '${LanguageService.tr('Analysis failed')}: ${e.toString().replaceAll('Exception:', '').trim()}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(
    String message, {
    required bool error,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.redAccent : null,
          duration: duration,
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
        child: RefreshIndicator(
          onRefresh: _fetchScanUsage,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_isOffline)
                Card(
                  color: isDark ? Colors.orange.shade900 : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            LanguageService.tr('You are offline. AI scanning requires an internet connection.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('AI scans today'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (_loadingUsage)
                              const LinearProgressIndicator()
                            else
                              Text(
                                _scanUsage == null
                                    ? LanguageService.tr('Unable to load scan usage')
                                    : '${_scanUsage!.used} / ${_scanUsage!.limit}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    image!,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Center(
                    child: Text(LanguageService.tr('Take or choose a food photo')),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : pickImageFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(LanguageService.tr('Gallery')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : pickImage,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(LanguageService.tr('Camera')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: loading || image == null ? null : analyzeFood,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  loading
                      ? LanguageService.tr('Analyzing...')
                      : LanguageService.tr('Analyze Food'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
