import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/shared/auth/application/auth_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/shared/address/presentation/viewmodels/address_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  DateTime _selectedDob = DateTime(2001, 1, 16);
  String _selectedLanguage = 'English';
  
  File? _pickedImageFile;
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authViewModelProvider).value;
    _nameController = TextEditingController(text: user?.name.isNotEmpty == true ? user!.name : 'Tanu Chouhan');
    _phoneController = TextEditingController(text: user?.phone?.isNotEmpty == true ? user!.phone! : '9301988718');
    _emailController = TextEditingController(text: user?.email.isNotEmpty == true ? user!.email : 'tanuchouhan161@gmaim.com');
    _selectedAvatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        Haptics.success();
        setState(() {
          _pickedImageFile = File(image.path);
          _selectedAvatarUrl = image.path;
        });
        if (mounted) {
          AppSnackbar.success(
            context,
            'Profile photo selected! Tap "Save Changes" to apply.',
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not access camera/gallery: $e');
      }
    }
  }

  void _changeProfilePhoto() {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Change Profile Photo 📷',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFECE0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use camera to capture photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFECE0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select photo from your gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFECE0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.face_rounded, color: AppColors.primary),
                ),
                title: const Text('3D Character Avatar'),
                subtitle: const Text('Use default high quality 3D avatar'),
                onTap: () {
                  Navigator.pop(ctx);
                  Haptics.success();
                  setState(() {
                    _pickedImageFile = null;
                    _selectedAvatarUrl = 'assets/images/user_avatar_3d.png';
                  });
                  AppSnackbar.success(context, '3D Character Avatar set!');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editNameDialog() {
    Haptics.light();
    final tempController = TextEditingController(text: _nameController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Full Name ✏️',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: tempController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Haptics.light();
                      if (tempController.text.trim().isNotEmpty) {
                        setState(() {
                          _nameController.text = tempController.text.trim();
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Update Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editEmailDialog() {
    Haptics.light();
    final tempController = TextEditingController(text: _emailController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Email Address ✉️',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: tempController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Haptics.light();
                      if (tempController.text.trim().isNotEmpty) {
                        setState(() {
                          _emailController.text = tempController.text.trim();
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Update Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editPhoneDialog() {
    Haptics.light();
    final tempController = TextEditingController(text: _phoneController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Phone Number 📞',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: tempController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '10-digit mobile number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      Haptics.light();
                      if (tempController.text.trim().isNotEmpty) {
                        setState(() {
                          _phoneController.text = tempController.text.trim();
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Update Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateOfBirth() async {
    Haptics.light();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  void _selectLanguageModal() {
    Haptics.light();
    final languages = ['English', 'Hindi (हिंदी)', 'Hinglish'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Language 🌐', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 12.h),
              ...languages.map((lang) {
                final isSel = _selectedLanguage.contains(lang.split(' ')[0]);
                return ListTile(
                  title: Text(lang, style: TextStyle(fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                  trailing: isSel ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    Haptics.light();
                    setState(() => _selectedLanguage = lang.split(' ')[0]);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _saveChanges() async {
    Haptics.success();

    // A picked image has to be UPLOADED before it can be saved.
    //
    // This previously passed _pickedImageFile.path straight through as the
    // avatar URL — a local device path like /data/user/0/.../cache/img.jpg. The
    // file never left the phone, so the picture looked right until the next
    // refresh, when the profile reloaded from the server and that unloadable
    // path fell back to the bundled placeholder.
    String? avatarUrlToSave = _selectedAvatarUrl;
    if (_pickedImageFile != null) {
      try {
        avatarUrlToSave = await ref
            .read(authRemoteDataSourceProvider)
            .uploadProfileImage(_pickedImageFile!.path);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload your photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Stop rather than silently saving the old avatar — the user asked for
        // a new photo and needs to know it did not happen.
        return;
      }
    }

    await ref.read(authViewModelProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          avatarUrl: avatarUrlToSave,
          dateOfBirth: _formatDate(_selectedDob),
        );

    if (mounted) {
      AppSnackbar.success(
        context,
        'Profile information updated successfully! 🎉',
        duration: const Duration(seconds: 2),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final addresses = ref.watch(addressViewModelProvider);
    final homeAddressText = addresses.isNotEmpty
        ? addresses.first.fullAddress
        : '123, Shastri Nagar, Jaipur, Rajasthan 302016, India';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28.sp, color: textColor),
          onPressed: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          children: [
            Text(
              'Edit Profile',
              style: TextStyle(
                color: textColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Update your profile information',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. AVATAR & PHOTO CHANGE SECTION
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96.r,
                          height: 96.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFECE0),
                            border: Border.all(
                              color: const Color(0xFFFFD4B8),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _pickedImageFile != null
                                ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                                : (_selectedAvatarUrl != null && _selectedAvatarUrl!.startsWith('/')
                                    ? Image.file(File(_selectedAvatarUrl!), fit: BoxFit.cover)
                                    : Image.asset(
                                        'assets/images/user_avatar_3d.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person_rounded,
                                          size: 54.sp,
                                          color: AppColors.primary,
                                        ),
                                      )),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePhoto,
                            child: Container(
                              padding: EdgeInsets.all(7.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6D00),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 15.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: _changeProfilePhoto,
                      child: Text(
                        'Change Profile Photo',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'JPG, PNG or WEBP. Max size 2MB',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 2. PERSONAL INFORMATION CARD
              _buildSectionTitle('Personal Information', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Full Name (Editable)
                    _buildEditableRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: _nameController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.edit_outlined,
                        size: 18.sp,
                        color: secondaryTextColor,
                      ),
                      onTap: _editNameDialog,
                    ),
                    _buildDivider(isDark),

                    // Mobile Number (Editable)
                    _buildEditableRow(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Mobile Number',
                      value: _phoneController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVerifiedBadge(),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.edit_outlined,
                            size: 16.sp,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                      onTap: _editPhoneDialog,
                    ),
                    _buildDivider(isDark),

                    // Email Address (Editable!)
                    _buildEditableRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email Address',
                      value: _emailController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVerifiedBadge(),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.edit_outlined,
                            size: 16.sp,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                      onTap: _editEmailDialog,
                    ),
                    _buildDivider(isDark),

                    // Date of Birth (Editable via DatePicker)
                    _buildEditableRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Birth',
                      value: _formatDate(_selectedDob),
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.sp,
                        color: secondaryTextColor,
                      ),
                      onTap: _selectDateOfBirth,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 3. ADDRESS CARD
              _buildSectionTitle('Address', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Home Address
                    _buildEditableRow(
                      icon: Icons.location_on_outlined,
                      label: 'Home Address',
                      value: homeAddressText,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                      ),
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.addAddress);
                      },
                    ),
                    _buildDivider(isDark),

                    // Add Work Address
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.addAddress);
                      },
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF3E0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.map_outlined,
                                color: const Color(0xFFFF6D00),
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Work Address (Optional)',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Add your work address for better delivery',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 4. PREFERENCES CARD
              _buildSectionTitle('Preferences', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Notification Preferences
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.notifications);
                      },
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF3E0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: const Color(0xFFFF6D00),
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification Preferences',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Manage your notification settings',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildDivider(isDark),

                    // Language
                    InkWell(
                      onTap: _selectLanguageModal,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF3E0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.language_rounded,
                                color: const Color(0xFFFF6D00),
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Language',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    _selectedLanguage,
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // 5. SAVE CHANGES BUTTON
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 14.w,
      endIndent: 14.w,
      color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            size: 11.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
    Widget? actionWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF6D00),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionWidget != null) ...[
              SizedBox(width: 8.w),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }
}
