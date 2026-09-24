import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton.dart';

/// Historique des notifications reçues (lecture, suppression par glissement).
class NotificationsScreen extends StatefulWidget {
  final bool embedded;

  const NotificationsScreen({super.key, this.embedded = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  AuthProvider get _auth => Provider.of<AuthProvider>(context, listen: false);
  ApiService get _api => Provider.of<ApiService>(context, listen: false);

  Future<void> _fetch({bool silent = false}) async {
    final user = _auth.user;
    if (user == null) return;
    try {
      final response = await _api.getNotifications(user.id);
      if (mounted) {
        setState(() {
          _notifications = response['notifications'] ?? [];
          _error = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _error = AppSnackbar.clean(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markRead(int index) async {
    final n = _notifications[index];
    final id = n['id'] as int;
    try {
      await _api.markNotificationAsRead(_auth.user!.id, id);
      if (!mounted) return;
      setState(() {
        final updated = Map<String, dynamic>.from(n)..['isRead'] = 1;
        _notifications[index] = updated;
      });
    } catch (e) {
      debugPrint('markNotificationAsRead: $e');
    }
  }

  Future<void> _delete(int index, {bool refetchOnError = false}) async {
    final id = _notifications[index]['id'] as int;
    try {
      await _api.deleteNotification(_auth.user!.id, id);
      if (!mounted) return;
      setState(() => _notifications.removeAt(index));
      AppSnackbar.info(context, 'Notification supprimée');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, AppSnackbar.clean(e));
      if (refetchOnError) _fetch();
    }
  }

  Future<void> _markAllRead() async {
    final unread = <int>[];
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i]['isRead'] != 1) unread.add(i);
    }
    for (final i in unread) {
      await _markRead(i);
    }
    if (mounted && unread.isNotEmpty) AppSnackbar.success(context, 'Tout est marqué comme lu');
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isRead'] != 1).length;
    final subtitle = unreadCount > 0 ? '$unreadCount non lue${unreadCount > 1 ? 's' : ''}' : 'Tout est à jour';

    final content = _isLoading
        ? const SkeletonList(count: 6, itemHeight: 92)
        : _error != null
            ? ErrorState(message: _error!, onRetry: _fetch)
            : _notifications.isEmpty
                ? RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView(
                      children: const [
                        SizedBox(height: 40),
                        EmptyState(
                          image: AppImages.reminders,
                          title: 'Aucune notification',
                          subtitle: 'Vous serez alerté ici pour vos rappels et les mises à jour de votre compte.',
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 100),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final id = n['id'] as int;
                        final isRead = n['isRead'] == 1;
                        return AnimatedFadeSlide(
                          index: index,
                          child: Dismissible(
                            key: Key('notif_$id'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _delete(index, refetchOnError: true),
                            background: Container(
                              decoration: BoxDecoration(color: AppColors.destructive, borderRadius: AppRadius.rLg),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                            ),
                            child: _NotificationCard(
                              title: n['titre']?.toString() ?? '',
                              body: n['contenu']?.toString() ?? '',
                              date: n['date']?.toString() ?? n['createdAt']?.toString(),
                              isRead: isRead,
                              onTap: isRead ? null : () => _markRead(index),
                              onDelete: () => _delete(index),
                            ),
                          ),
                        );
                      },
                    ),
                  );

    final actions = [
      if (unreadCount > 0)
        IconButton(tooltip: 'Tout marquer comme lu', onPressed: _markAllRead, icon: const Icon(Icons.done_all_rounded)),
      IconButton(tooltip: 'Actualiser', onPressed: _fetch, icon: const Icon(Icons.refresh_rounded)),
    ];

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PageHeader(
                title: 'Notifications',
                subtitle: subtitle,
                actions: [
                  if (unreadCount > 0) HeaderIconButton(icon: Icons.done_all_rounded, tooltip: 'Tout marquer comme lu', onTap: _markAllRead),
                  HeaderIconButton(icon: Icons.refresh_rounded, tooltip: 'Actualiser', onTap: _fetch),
                ],
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(title: 'Notifications', subtitle: subtitle, actions: actions),
      body: content,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final String? date;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.title,
    required this.body,
    this.date,
    required this.isRead,
    this.onTap,
    required this.onDelete,
  });

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final local = d.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    final hm = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Aujourd\'hui · $hm';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} · $hm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDate(date);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      color: isRead ? AppColors.surface : AppColors.primaryLight.withValues(alpha: 0.55),
      borderColor: isRead ? null : AppColors.primary.withValues(alpha: 0.25),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(
            icon: isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
            color: isRead ? AppColors.mutedForeground : AppColors.primary,
            size: 42,
            iconSize: 21,
            background: isRead ? AppColors.surfaceMuted : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isRead) ...[
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
                ],
                if (dateLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(dateLabel, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
