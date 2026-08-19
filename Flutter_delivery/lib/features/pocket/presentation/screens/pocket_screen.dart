import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/main/presentation/screens/main_screen.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/services/sound_service.dart';

class PocketScreen extends ConsumerStatefulWidget {
  const PocketScreen({super.key});

  @override
  ConsumerState<PocketScreen> createState() => _PocketScreenState();
}

class _PocketScreenState extends ConsumerState<PocketScreen> {
  static const Color _onlineGreen = Color(0xFF1EBE5D);

  bool _loading = true;
  String? _error;
  bool _withdrawing = false;
  bool _depositing = false;
  double? _pendingDepositAmount;

  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _pocketData;
  Map<String, dynamic>? _cashLimit;
  Map<String, dynamic>? _todayEarnings;

  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onDepositSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onDepositError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onDepositExternalWallet);
    _loadAll();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(walletRepositoryProvider);
    final results = await Future.wait<Result<Map<String, dynamic>, AppError>>(
      [
        repo.getWallet(),
        repo.getPocketDetails(),
        repo.getCashLimit(),
        repo.getEarnings(period: 'today'),
      ],
    );

    Map<String, dynamic>? wallet;
    Map<String, dynamic>? pocketData;
    Map<String, dynamic>? cashLimit;
    Map<String, dynamic>? todayEarnings;
    String? error;

    results[0].when(
      success: (data) => wallet = data['wallet'] as Map<String, dynamic>? ?? data,
      failure: (e) => error = e.message,
    );
    results[1].when(
      success: (data) => pocketData = data,
      failure: (e) => error ??= e.message,
    );
    results[2].when(
      success: (data) => cashLimit = data,
      failure: (_) {},
    );
    results[3].when(
      success: (data) => todayEarnings = data['summary'] as Map<String, dynamic>? ?? data,
      failure: (_) {},
    );

    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _pocketData = pocketData;
      _cashLimit = cashLimit;
      _todayEarnings = todayEarnings;
      _error = error;
      _loading = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showWithdrawDialog() async {
    final pocketBalance = (_wallet?['pocketBalance'] as num?)?.toDouble() ?? 0;
    final minWithdraw = (_cashLimit?['deliveryWithdrawalLimit'] as num?)?.toDouble() ?? 0;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw to bank'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount',
              helperText:
                  'Available: ₹${pocketBalance.toStringAsFixed(0)} · Min: ₹${minWithdraw.toStringAsFixed(0)}',
            ),
            validator: (value) {
              final amt = double.tryParse(value ?? '');
              if (amt == null || amt <= 0) return 'Enter a valid amount';
              if (amt < minWithdraw) return 'Minimum withdrawal is ₹${minWithdraw.toStringAsFixed(0)}';
              if (amt > pocketBalance) return 'Amount exceeds available balance';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(double.parse(controller.text));
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (amount == null) return;

    setState(() => _withdrawing = true);
    final result = await ref.read(walletRepositoryProvider).withdraw(amount);
    if (!mounted) return;
    setState(() => _withdrawing = false);
    result.when(
      success: (_) {
        _showSnack('Withdrawal request submitted');
        _loadAll();
      },
      failure: (e) => _showSnack(e.message),
    );
  }

  Future<void> _showDepositDialog() async {
    final cashInHand = (_wallet?['cashInHand'] as num?)?.toDouble() ?? 0;
    if (cashInHand <= 0) {
      _showSnack('No cash in hand to deposit');
      return;
    }
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deposit cash to company'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount',
              helperText: 'Cash in hand: ₹${cashInHand.toStringAsFixed(0)}',
            ),
            validator: (value) {
              final amt = double.tryParse(value ?? '');
              if (amt == null || amt <= 0) return 'Enter a valid amount';
              if (amt > cashInHand) return 'Amount exceeds cash in hand';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(double.parse(controller.text));
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (amount == null) return;
    await _startDeposit(amount);
  }

  Future<void> _startDeposit(double amount) async {
    setState(() => _depositing = true);
    final result = await ref.read(walletRepositoryProvider).createDepositOrder(amount);
    if (!mounted) return;
    result.when(
      success: (data) {
        final razorpay = data['razorpay'] as Map<String, dynamic>?;
        final key = razorpay?['key'] as String?;
        final orderId = razorpay?['orderId'] as String?;
        if (razorpay == null || key == null || orderId == null) {
          setState(() => _depositing = false);
          _showSnack('Unable to start deposit — payment gateway not configured');
          return;
        }

        _pendingDepositAmount = amount;
        final authState = ref.read(authControllerProvider);
        final user = authState is AuthAuthenticated ? authState.user : null;
        final options = {
          'key': key,
          'order_id': orderId,
          'amount': razorpay['amount'],
          'currency': razorpay['currency'] ?? 'INR',
          'name': 'Suvio Delivery Partner',
          'description': 'Cash deposit to company',
          'prefill': {
            if (user?.name != null) 'name': user!.name,
            if (user?.email != null && user!.email!.isNotEmpty) 'email': user.email,
            'contact': user?.phone ?? '',
          },
        };
        try {
          _razorpay.open(options);
        } catch (e) {
          setState(() => _depositing = false);
          _pendingDepositAmount = null;
          _showSnack('Unable to open payment gateway');
        }
      },
      failure: (error) {
        setState(() => _depositing = false);
        _showSnack(error.message);
      },
    );
  }

  Future<void> _onDepositSuccess(PaymentSuccessResponse response) async {
    final amount = _pendingDepositAmount;
    if (amount == null) {
      setState(() => _depositing = false);
      return;
    }
    final result = await ref.read(walletRepositoryProvider).verifyDeposit(
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _depositing = false);
    _pendingDepositAmount = null;
    result.when(
      success: (_) {
        _showSnack('Cash deposited successfully');
        _loadAll();
      },
      failure: (error) => _showSnack(error.message),
    );
  }

  void _onDepositError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _depositing = false);
    _pendingDepositAmount = null;
    _showSnack(response.message?.isNotEmpty == true ? response.message! : 'Payment failed');
  }

  void _onDepositExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _depositing = false);
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack (main_screen.dart) keeps this screen alive across tab
    // switches, so initState only fires once at app start. Reload wallet
    // data whenever this tab becomes active so earnings from a
    // just-completed delivery show up without a manual pull-to-refresh.
    ref.listen<int>(mainTabIndexProvider, (previous, next) {
      if (next == 1 && previous != 1) _loadAll();
    });
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.appBarTheme.iconTheme?.color,
          ),
          onPressed: () => ref.read(mainTabIndexProvider.notifier).setIndex(0),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POCKET',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp),
            ),
            Text(
              'YOUR MILESTONES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, textColor, subTextColor)
              : RefreshIndicator(
                  onRefresh: () async {
                    SoundService.playRefresh();
                    await _loadAll();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      top: 10.h,
                      bottom: 120.h,
                    ),
                    child: Column(
                      children: [
                        _buildWeeklyEarningsCard(theme),
                        SizedBox(height: 16.h),
                        _buildWalletBalanceCard(theme, isDarkMode, textColor, subTextColor),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                theme: theme,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                icon: Icons.local_shipping_outlined,
                                label: "Today's Trips",
                                value: '${(_todayEarnings?['totalOrders'] as num?)?.toInt() ?? 0}',
                                footer:
                                    '₹${((_todayEarnings?['totalEarnings'] as num?) ?? 0).toStringAsFixed(0)} earned',
                                footerColor: _onlineGreen,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildRatingCard(theme, textColor, subTextColor)),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _buildEarningsBreakupCard(theme, textColor, subTextColor),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Color textColor, Color? subTextColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40.sp, color: subTextColor),
            SizedBox(height: 12.h),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard(ThemeData theme, Color textColor, Color? subTextColor) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final rating = user?.rating;
    final totalRatings = user?.totalRatings ?? 0;

    return _buildStatCard(
      theme: theme,
      textColor: textColor,
      subTextColor: subTextColor,
      icon: Icons.star_rounded,
      label: 'Rating',
      value: rating != null ? rating.toStringAsFixed(2) : '—',
      footer: totalRatings > 0 ? '$totalRatings ratings' : 'No ratings yet',
      footerColor: Colors.amber[700]!,
      valueColor: Colors.amber[700],
    );
  }

  Widget _buildWeeklyEarningsCard(ThemeData theme) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final summary = _pocketData?['summary'] as Map<String, dynamic>?;
    final totalEarning = (summary?['totalEarning'] as num?)?.toDouble() ?? 0;
    final totalBonus = (summary?['totalBonus'] as num?)?.toDouble() ?? 0;
    final grandTotal = (summary?['grandTotal'] as num?)?.toDouble() ?? 0;
    final trips = (_pocketData?['trips'] as List<dynamic>?) ?? [];

    final perDay = <int, double>{};
    for (final trip in trips.whereType<Map<String, dynamic>>()) {
      final dateStr = trip['date'] as String? ?? trip['createdAt'] as String?;
      // Convert before bucketing: the API sends UTC, so a trip completed at
      // 00:30 IST would otherwise be counted against the previous weekday.
      final dt = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
      if (dt == null) continue;
      final amt = (trip['earningAmount'] as num?)?.toDouble() ??
          (trip['deliveryEarning'] as num?)?.toDouble() ??
          (trip['amount'] as num?)?.toDouble() ??
          0;
      perDay[dt.weekday] = (perDay[dt.weekday] ?? 0) + amt;
    }
    final maxVal = perDay.values.fold<double>(0, (a, b) => a > b ? a : b);
    final values = List.generate(
      7,
      (i) => maxVal <= 0 ? 0.0 : (perDay[i + 1] ?? 0) / maxVal,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, const Color(0xFFFF9853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            '₹${grandTotal.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Earnings ₹${totalEarning.toStringAsFixed(0)} · Bonus ₹${totalBonus.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 18.h),
          if (maxVal > 0) ...[
            SizedBox(
              height: 70.h,
              width: double.infinity,
              child: CustomPaint(painter: _WeeklyChartPainter(values: values)),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days
                  .map(
                    (d) => Text(
                      d,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else
            Text(
              'No earnings yet this week',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletBalanceCard(
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
    Color? subTextColor,
  ) {
    final pocketBalance = (_wallet?['pocketBalance'] as num?)?.toDouble() ?? 0;
    final cashInHand = (_wallet?['cashInHand'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Balance',
                      style: TextStyle(fontSize: 12.sp, color: subTextColor, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '₹${pocketBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22.sp,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _withdrawing ? null : _showWithdrawDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _onlineGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                child: _withdrawing
                    ? SizedBox(
                        width: 16.sp,
                        height: 16.sp,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Withdraw',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
                      ),
              ),
            ],
          ),
          if (cashInHand > 0) ...[
            SizedBox(height: 16.h),
            Divider(height: 1, color: subTextColor?.withOpacity(0.2)),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash in Hand',
                        style: TextStyle(fontSize: 12.sp, color: subTextColor, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '₹${cashInHand.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18.sp,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _depositing ? null : _showDepositDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor),
                    padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: _depositing
                      ? SizedBox(
                          width: 16.sp,
                          height: 16.sp,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                        )
                      : Text(
                          'Deposit Cash',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required Color textColor,
    required Color? subTextColor,
    required IconData icon,
    required String label,
    required String value,
    required String footer,
    required Color footerColor,
    Color? valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: subTextColor),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.sp, color: subTextColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22.sp,
              color: valueColor ?? textColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            footer,
            style: TextStyle(fontSize: 11.sp, color: footerColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakupCard(ThemeData theme, Color textColor, Color? subTextColor) {
    final summary = _pocketData?['summary'] as Map<String, dynamic>?;
    final rows = [
      ('Delivery Earnings', (summary?['totalEarning'] as num?)?.toDouble() ?? 0),
      ('Bonus', (summary?['totalBonus'] as num?)?.toDouble() ?? 0),
      ('Total', (summary?['grandTotal'] as num?)?.toDouble() ?? 0),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Breakup',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
          ),
          SizedBox(height: 16.h),
          for (int i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].$1,
                  style: TextStyle(fontSize: 13.sp, color: subTextColor),
                ),
                Text(
                  '₹${rows[i].$2.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: textColor),
                ),
              ],
            ),
            if (i != rows.length - 1) SizedBox(height: 14.h),
          ],
        ],
      ),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  final List<double> values;

  _WeeklyChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final points = <Offset>[];
    final step = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height * (1 - values[i]);
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final mid = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
      linePath.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(points.last, 4.5, dotPaint);
    canvas.drawCircle(
      points.last,
      7,
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
