import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/language_service.dart';
import '../../../core/services/sync_service.dart';

class SyncCenterModal extends StatefulWidget {
  const SyncCenterModal({super.key});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => const SyncCenterModal(),
    );
  }

  @override
  State<SyncCenterModal> createState() => _SyncCenterModalState();
}

class _SyncCenterModalState extends State<SyncCenterModal>
    with SingleTickerProviderStateMixin {
  final SyncService _syncService = SyncService.instance;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _handleManualSync() async {
    _spinController.repeat();
    await _syncService.syncNow();
    if (mounted) {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF22C55E);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return ValueListenableBuilder<bool>(
          valueListenable: _syncService.isOnlineNotifier,
          builder: (context, isOnline, _) {
            return ValueListenableBuilder<SyncStatus>(
              valueListenable: _syncService.statusNotifier,
              builder: (context, syncStatus, _) {
                return ValueListenableBuilder<List<SyncItem>>(
                  valueListenable: _syncService.pendingItemsNotifier,
                  builder: (context, pendingItems, _) {
                    final isSynced = pendingItems.isEmpty && syncStatus != SyncStatus.syncing;
                    final lastSyncStr = _syncService.lastSyncTime != null
                        ? DateFormat('hh:mm a').format(_syncService.lastSyncTime!)
                        : 'Just now';

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // Top Drag Handle
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.sync_rounded,
                                      color: primaryColor,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LanguageService.tr("Data Synchronization"),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${LanguageService.tr('Last synced')}: $lastSyncStr",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Connection & Sync Status Overview Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      LanguageService.tr("Connection Status"),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? primaryColor.withValues(alpha: 0.15)
                                            : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isOnline
                                                ? Icons.wifi_rounded
                                                : Icons.wifi_off_rounded,
                                            size: 14,
                                            color: isOnline
                                                ? primaryColor
                                                : const Color(0xFFEF4444),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isOnline
                                                ? LanguageService.tr("Online")
                                                : LanguageService.tr("Offline"),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isOnline
                                                  ? primaryColor
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      LanguageService.tr("Sync State"),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      isSynced
                                          ? "✓ ${LanguageService.tr('All data synced')}"
                                          : syncStatus == SyncStatus.syncing
                                              ? "↻ ${LanguageService.tr('Syncing...')}"
                                              : "⟳ ${pendingItems.length} ${LanguageService.tr('changes waiting to sync')}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSynced
                                            ? primaryColor
                                            : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Pending Items Section Title
                          Text(
                            LanguageService.tr("Pending Queue"),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Pending Queue List
                          Expanded(
                            child: pendingItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 48,
                                          color: primaryColor.withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          LanguageService.tr("All data is up to date"),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: pendingItems.length,
                                    itemBuilder: (context, index) {
                                      final item = pendingItems[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.black.withValues(alpha: 0.04),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.pending_actions_rounded,
                                                  color: Color(0xFFF59E0B),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat('MMM d, hh:mm a').format(item.timestamp),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                LanguageService.tr("Pending sync"),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Manual Sync Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: isOnline ? _handleManualSync : null,
                              icon: RotationTransition(
                                turns: _spinController,
                                child: const Icon(Icons.sync_rounded),
                              ),
                              label: Text(
                                LanguageService.tr("Sync Now"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                );
              },
            );
          },
        );
      },
    );
  }
}
