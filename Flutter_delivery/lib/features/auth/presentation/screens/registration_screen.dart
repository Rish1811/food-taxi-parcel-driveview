import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/referral_tracking_service.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_widgets.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.phone = ''});

  final String phone;

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  String get _phone {
    if (widget.phone.isNotEmpty) return widget.phone;
    final authState = ref.read(authControllerProvider);
    return authState is AuthNeedsRegistration ? authState.phone : '';
  }

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _vehicleNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenseController = TextEditingController();
  final _panController = TextEditingController();
  final _aadharController = TextEditingController();
  final _referralController = TextEditingController();

  String _vehicleType = 'bike';
  final _vehicleTypes = const ['bike', 'scooter', 'bicycle', 'car'];

  File? _profilePhoto;
  File? _aadharPhoto;
  File? _panPhoto;
  File? _licensePhoto;
  File? _upiQrCode;

  bool _isSubmitting = false;
  String? _errorText;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    final code = await ReferralTrackingService.getReferralCode();
    if (code != null && code.isNotEmpty && mounted) {
      setState(() {
        _referralController.text = code;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _licenseController.dispose();
    _panController.dispose();
    _aadharController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(File) onPicked) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_profilePhoto == null ||
        _aadharPhoto == null ||
        _panPhoto == null ||
        _licensePhoto == null) {
      setState(() => _errorText = 'Please upload all required documents');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final formData = FormData.fromMap({
      'name': _nameController.text.trim(),
      'phone': _phone,
      'countryCode': '+91',
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'vehicleType': _vehicleType,
      'vehicleName': _vehicleNameController.text.trim(),
      'vehicleNumber': _vehicleNumberController.text.trim().toUpperCase(),
      'drivingLicenseNumber': _licenseController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[\s-]'), ''),
      'panNumber': _panController.text.trim().toUpperCase(),
      'aadharNumber': _aadharController.text.trim(),
      if (_referralController.text.trim().isNotEmpty)
        'ref': _referralController.text.trim(),
      'platform': 'mobile',
      'profilePhoto': await MultipartFile.fromFile(_profilePhoto!.path),
      'aadharPhoto': await MultipartFile.fromFile(_aadharPhoto!.path),
      'panPhoto': await MultipartFile.fromFile(_panPhoto!.path),
      'drivingLicensePhoto': await MultipartFile.fromFile(
        _licensePhoto!.path,
      ),
      if (_upiQrCode != null)
        'upiQrCode': await MultipartFile.fromFile(_upiQrCode!.path),
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .register(formData);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {},
      failure: (error) => setState(() => _errorText = error.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Registration')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            children: [
              const AuthSectionTitle('Personal details'),
              _textField(_nameController, 'Full name', required: true),
              SizedBox(height: 12.h),
              TextFormField(
                initialValue: '+91 $_phone',
                enabled: false,
                decoration: authInputDecoration(context, label: 'Mobile number'),
              ),
              SizedBox(height: 12.h),
              _textField(
                _emailController,
                'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              _textField(_addressController, 'Address'),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: _textField(_cityController, 'City')),
                  SizedBox(width: 12.w),
                  Expanded(child: _textField(_stateController, 'State')),
                ],
              ),

              const AuthSectionTitle('Vehicle details'),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: authInputDecoration(context, label: 'Vehicle type'),
                items: _vehicleTypes
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v[0].toUpperCase() + v.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _vehicleType = value ?? _vehicleType),
              ),
              SizedBox(height: 12.h),
              _textField(_vehicleNameController, 'Vehicle name/model'),
              SizedBox(height: 12.h),
              _textField(
                _vehicleNumberController,
                'Vehicle number',
                required: true,
              ),

              const AuthSectionTitle('KYC details'),
              _textField(
                _licenseController,
                'Driving license number',
                required: true,
                validator: (value) {
                  final v =
                      (value ?? '').trim().toUpperCase().replaceAll(
                        RegExp(r'[\s-]'),
                        '',
                      );
                  if (!RegExp(r'^[A-Z]{2}[0-9A-Z]{8,16}$').hasMatch(v)) {
                    return 'Enter a valid license number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              _textField(
                _panController,
                'PAN number',
                required: true,
                validator: (value) {
                  final v = (value ?? '').trim().toUpperCase();
                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                    return 'Enter a valid PAN number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              _textField(
                _aadharController,
                'Aadhar number',
                required: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (!RegExp(r'^\d{12}$').hasMatch(v)) {
                    return 'Enter a valid 12-digit Aadhar number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              _textField(_referralController, 'Referral code (optional)'),

              const AuthSectionTitle('Upload documents'),
              _docPickerRow('Profile photo', _profilePhoto, () =>
                  _pickImage((f) => _profilePhoto = f)),
              _docPickerRow('Aadhar card photo', _aadharPhoto, () =>
                  _pickImage((f) => _aadharPhoto = f)),
              _docPickerRow('PAN card photo', _panPhoto, () =>
                  _pickImage((f) => _panPhoto = f)),
              _docPickerRow('Driving license photo', _licensePhoto, () =>
                  _pickImage((f) => _licensePhoto = f)),
              _docPickerRow('UPI QR code (optional)', _upiQrCode, () =>
                  _pickImage((f) => _upiQrCode = f)),

              if (_errorText != null) ...[
                SizedBox(height: 12.h),
                Text(
                  _errorText!,
                  style: TextStyle(color: Colors.redAccent, fontSize: 13.sp),
                ),
              ],
              SizedBox(height: 24.h),
              AuthPrimaryButton(
                label: 'Submit for Review',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: authInputDecoration(context, label: label).copyWith(
        counterText: maxLength != null ? '' : null,
      ),
      validator:
          validator ??
          (required
              ? (value) => (value == null || value.trim().isEmpty)
                    ? 'Required'
                    : null
              : null),
    );
  }

  Widget _docPickerRow(String label, File? file, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: file != null
                    ? Image.file(
                        file,
                        width: 48.w,
                        height: 48.w,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48.w,
                        height: 48.w,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.upload_file_rounded,
                          color: AppTheme.primaryColor,
                          size: 22.sp,
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                file != null ? 'Change' : 'Upload',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
