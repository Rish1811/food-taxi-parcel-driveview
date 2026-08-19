import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/models/delivery_partner.dart';
import '../../data/profile_repository.dart';

class DriverDetailsScreen extends ConsumerWidget {
  const DriverDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final bgColor = isDarkMode ? const Color(0xFF161925) : const Color(0xFFF9FAFB);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Details',
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => context.push('/driver-id-card'),
            child: Container(
              margin: EdgeInsets.only(right: 20.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ID: ',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _partnerId(user),
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            _buildProfileCard(theme, textColor, user),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(child: _buildRatingCard(theme, textColor, user)),
                SizedBox(width: 15.w),
                Expanded(child: _buildTotalRatingsCard(theme, textColor, user)),
              ],
            ),
            SizedBox(height: 30.h),
            Text(
              'VEHICLE ASSETS',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 12.h),
            _buildVehicleCard(theme, textColor, user),
            SizedBox(height: 30.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BANK & PAYMENTS',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () => _openBankEditDialog(context, ref, user),
                  child: Text(
                    'EDIT',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildBankCard(context, ref, user),
          ],
        ),
      ),
    );
  }

  String _partnerId(DeliveryPartner? user) {
    final id = user?.id ?? '';
    if (id.length < 8) return id.isEmpty ? '—' : 'DP-${id.toUpperCase()}';
    return 'DP-${id.substring(id.length - 8).toUpperCase()}';
  }

  (IconData, Color, String) _statusInfo(DeliveryPartner? user) {
    if (user == null) return (Icons.hourglass_empty, Colors.grey, 'Unknown');
    if (user.isApproved) return (Icons.check_circle_outline, Colors.green, 'Approved');
    if (user.isRejected) return (Icons.cancel_outlined, Colors.redAccent, 'Rejected');
    if (user.isDeactivated) return (Icons.block, Colors.grey, 'Deactivated');
    return (Icons.access_time, Colors.orange, 'Pending');
  }

  Widget _buildProfileCard(ThemeData theme, Color textColor, DeliveryPartner? user) {
    final (statusIcon, statusColor, statusLabel) = _statusInfo(user);
    final location = [
      if (user?.city != null && user!.city!.isNotEmpty) user.city,
      if (user?.state != null && user!.state!.isNotEmpty) user.state,
    ].join(', ');

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.grey[200],
                backgroundImage: user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty
                    ? NetworkImage(AppConstants.resolveMediaUrl(user.profilePhoto))
                    : null,
                child: user?.profilePhoto == null || user!.profilePhoto!.isEmpty
                    ? Icon(Icons.person, color: Colors.grey[500])
                    : null,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.name ?? 'Delivery Partner',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user?.isApproved == true) ...[
                          SizedBox(width: 6.w),
                          Icon(Icons.verified, color: Colors.green, size: 18.sp),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      location.isNotEmpty ? 'Delivery Partner • $location' : 'Delivery Partner',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18.sp),
                      SizedBox(width: 6.w),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, color: textColor, size: 18.sp),
                      SizedBox(width: 6.w),
                      Text(
                        user?.phone ?? '—',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(ThemeData theme, Color textColor, DeliveryPartner? user) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RATING',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                ),
              ),
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_border, color: theme.primaryColor, size: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            user?.rating != null ? user!.rating!.toStringAsFixed(2) : 'New',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRatingsCard(ThemeData theme, Color textColor, DeliveryPartner? user) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL RATINGS',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                ),
              ),
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_border, color: Colors.grey, size: 14.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            user?.totalRatings != null ? '${user!.totalRatings}' : '-',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(ThemeData theme, Color textColor, DeliveryPartner? user) {
    final parts = [
      if (user?.vehicleType != null && user!.vehicleType!.isNotEmpty)
        user.vehicleType!.toUpperCase(),
      if (user?.vehicleNumber != null && user!.vehicleNumber!.isNotEmpty) user.vehicleNumber,
    ];
    final label = parts.isNotEmpty ? parts.join(' • ') : 'Not set';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(Icons.motorcycle, color: theme.primaryColor, size: 28.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VEHICLE DETAILS',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBankEditDialog(BuildContext context, WidgetRef ref, DeliveryPartner? user) {
    showDialog(
      context: context,
      builder: (dialogContext) => _BankEditDialog(user: user, ref: ref),
    ).then((updated) {
      if (updated == true) {
        ref.read(authControllerProvider.notifier).checkAuthStatus();
      }
    });
  }

  Widget _buildBankCard(BuildContext context, WidgetRef ref, DeliveryPartner? user) {
    final accountNumber = user?.bankAccountNumber;
    final hasBank = accountNumber != null && accountNumber.isNotEmpty;
    final masked = hasBank && accountNumber.length >= 4
        ? 'XXXX XXXX XXXX ${accountNumber.substring(accountNumber.length - 4)}'
        : (hasBank ? accountNumber : null);

    return GestureDetector(
      onTap: hasBank ? null : () => _openBankEditDialog(context, ref, user),
      child: Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF10141D),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BANK ACCOUNT',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      hasBank ? (user?.bankName ?? 'Bank Account') : 'Link Account',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.account_balance, color: Colors.white, size: 24.sp),
                ),
              ],
            ),
            SizedBox(height: 30.h),
            Text(
              masked ?? 'No account linked yet',
              style: TextStyle(
                fontSize: 16.sp,
                letterSpacing: hasBank ? 2 : 0,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (hasBank) ...[
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCOUNT HOLDER',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        user?.bankAccountHolderName ?? '—',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'IFSC CODE',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        user?.bankIfscCode ?? '—',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankEditDialog extends StatefulWidget {
  const _BankEditDialog({required this.user, required this.ref});

  final DeliveryPartner? user;
  final WidgetRef ref;

  @override
  State<_BankEditDialog> createState() => _BankEditDialogState();
}

class _BankEditDialogState extends State<_BankEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderController;
  late final TextEditingController _accountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _upiController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _holderController = TextEditingController(text: widget.user?.bankAccountHolderName ?? '');
    _accountController = TextEditingController(text: widget.user?.bankAccountNumber ?? '');
    _ifscController = TextEditingController(text: widget.user?.bankIfscCode ?? '');
    _bankNameController = TextEditingController(text: widget.user?.bankName ?? '');
    _upiController = TextEditingController(text: widget.user?.upiId ?? '');
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await widget.ref.read(profileRepositoryProvider).updateBankDetails(
      accountHolderName: _holderController.text.trim(),
      accountNumber: _accountController.text.trim(),
      ifscCode: _ifscController.text.trim(),
      bankName: _bankNameController.text.trim(),
      upiId: _upiController.text.trim().isEmpty ? null : _upiController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bank Details',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, color: Colors.grey, size: 24.sp),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24.r,
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _holderController,
                        label: 'Account Holder Name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _accountController,
                        label: 'Account Number',
                        icon: Icons.numbers_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _ifscController,
                        label: 'IFSC Code',
                        icon: Icons.account_balance_outlined,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _bankNameController,
                        label: 'Bank Name',
                        icon: Icons.corporate_fare_outlined,
                      ),
                      SizedBox(height: 16.h),
                      _buildTextField(
                        controller: _upiController,
                        label: 'UPI ID (optional)',
                        icon: Icons.qr_code_scanner_outlined,
                        isRequired: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save Details',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool isRequired = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800] : Colors.grey[100];
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20.sp),
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
      validator: isRequired
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
    );
  }
}
