import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';

class TaxiEditProfileScreen extends ConsumerStatefulWidget {
  const TaxiEditProfileScreen({super.key});

  @override
  ConsumerState<TaxiEditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<TaxiEditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  String _gender = '';
  String? _profileImage;
  File? _pickedImage;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _gender = user?.gender ?? '';
    _profileImage = user?.profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Edit profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildAvatar()),
            const SizedBox(height: 32),
            AppTextField(controller: _nameController, label: 'Full name', hint: 'Your name'),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Text('Gender', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final g in ['male', 'female', 'other'])
                  ChoiceChip(
                    label: Text(g[0].toUpperCase() + g.substring(1)),
                    selected: _gender == g,
                    onSelected: (_) => setState(() => _gender = g),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            TaxiPrimaryButton(label: 'Save changes', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: TaxiColors.primary.withValues(alpha: 0.08),
          backgroundImage: _pickedImage != null
              ? FileImage(_pickedImage!)
              : (_profileImage != null && _profileImage!.isNotEmpty
                  ? CachedNetworkImageProvider(_profileImage!)
                  : null) as ImageProvider?,
          child: _pickedImage == null && (_profileImage == null || _profileImage!.isEmpty)
              ? const Icon(Icons.person_rounded, size: 44, color: TaxiColors.primary)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _uploadingImage ? null : _pickImage,
            child: Container(
              height: 36,
              width: 36,
              decoration: const BoxDecoration(color: TaxiColors.primary, shape: BoxShape.circle),
              child: _uploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _pickedImage = file;
      _uploadingImage = true;
    });
    try {
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final secureUrl = await ref.read(taxiAuthRepositoryProvider).uploadProfileImage(dataUrl);
      setState(() => _profileImage = secureUrl);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(taxiAuthRepositoryProvider).updateProfile({
        'name': _nameController.text.trim(),
        if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
        if (_gender.isNotEmpty) 'gender': _gender,
        if (_profileImage != null) 'profileImage': _profileImage,
      });
      ref.read(authControllerProvider.notifier).updateUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
