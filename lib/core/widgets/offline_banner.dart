import 'dart:async';

import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/sync_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final SyncService _syncService = SyncService.instance;
  bool _showReconnectedBanner = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _syncService.isOnlineNotifier.addListener(_onNetChanged);
  }

  @override
  void dispose() {
    _syncService.isOnlineNotifier.removeListener(_onNetChanged);
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _onNetChanged() {
    final isOnline = _syncService.isOnlineNotifier.value;
    if (isOnline) {
      setState(() => _showReconnectedBanner = true);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showReconnectedBanner = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _syncService.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<SyncStatus>(
          valueListenable: _syncService.statusNotifier,
          builder: (context, syncStatus, _) {
            if (!isOnline) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF334155), Color(0xFF1E293B)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${LanguageService.tr('Offline Mode')}: ",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: LanguageService.tr(
                                "Your changes will sync when you're back online.",
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_showReconnectedBanner) {
              final isSyncing = syncStatus == SyncStatus.syncing;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF15803D), Color(0xFF22C55E)],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSyncing
                          ? Icons.sync_rounded
                          : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSyncing
                            ? "${LanguageService.tr('Back Online')} ✓ — ${LanguageService.tr('Syncing your latest changes...')}"
                            : "${LanguageService.tr('All changes synced')} ✓",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
