import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/services/sound_service.dart';
import '../../data/notifications_repository.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(notificationsRepositoryProvider).getInbox(limit: 50);
    if (!mounted) return;
    result.when(
      success: (data) {
        final items = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        setState(() {
          _items = items;
          _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      },
      failure: (e) => setState(() {
        _error = e.message;
        _loading = false;
      }),
    );
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['isRead'] == true) return;
    final id = (item['_id'] ?? item['id'])?.toString();
    if (id == null) return;
    final result = await ref.read(notificationsRepositoryProvider).markRead(id);
    if (!mounted) return;
    result.when(
      success: (_) => setState(() {
        item['isRead'] = true;
        if (_unreadCount > 0) _unreadCount--;
      }),
      failure: (_) {},
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will remove all notifications. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(notificationsRepositoryProvider).deleteAll();
    if (!mounted) return;
    result.when(
      success: (_) => setState(() {
        _items = const [];
        _unreadCount = 0;
      }),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = _monthAbbr[dt.month - 1];
    var hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                color: textColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_unreadCount > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$_unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 18.sp),
              label: Text(
                'Clear All',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(width: 8.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          SoundService.playRefresh();
          await _load();
        },
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _items.isEmpty
                    ? _buildEmptyState(theme, textColor)
                    : ListView.builder(
                        padding: EdgeInsets.all(20.w),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: GestureDetector(
                              onTap: () => _markRead(item),
                              child: _buildNotificationCard(
                                theme,
                                title: (item['title'] ?? '').toString(),
                                subtitle: (item['message'] ?? '').toString(),
                                time: _formatTime(item['createdAt'] as String?),
                                isUnread: item['isRead'] != true,
                                textColor: textColor,
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        SizedBox(height: 100.h),
        Icon(Icons.error_outline, color: Colors.grey[400], size: 40.sp),
        SizedBox(height: 16.h),
        Text(
          _error ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14.sp),
        ),
        SizedBox(height: 16.h),
        Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color textColor) {
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        SizedBox(height: 100.h),
        Icon(Icons.notifications_none, color: Colors.grey[400], size: 48.sp),
        SizedBox(height: 16.h),
        Text(
          'No notifications yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isUnread ? theme.primaryColor.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnread) ...[
            Container(
              margin: EdgeInsets.only(top: 6.h),
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.w),
          ] else ...[
            SizedBox(width: 20.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14.sp, color: Colors.grey[400]),
                    SizedBox(width: 6.w),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Large Stylized Bell Icon
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.2),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_active,
                  color: theme.primaryColor,
                  size: 40.sp,
                ),
                if (isUnread)
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Container(
                      width: 10.r,
                      height: 10.r,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primaryColor, width: 2),
                      ),
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
