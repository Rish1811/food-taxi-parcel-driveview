import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/design_system/components/ride/empty_state.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/home/application/saved_places_provider.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Saved places',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: places.isEmpty
          ? EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No saved places yet',
              message: 'Add your home, work, or favorite spots for faster booking.',
              actionLabel: 'Add a place',
              onAction: () => _showAddSheet(context, ref),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return ListTile(
                  leading: Icon(
                    place.type == 'home'
                        ? Icons.home_rounded
                        : place.type == 'work'
                            ? Icons.work_rounded
                            : Icons.bookmark_rounded,
                    color: TaxiColors.primary,
                  ),
                  title: Text(place.label),
                  subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => ref.read(savedPlacesProvider.notifier).remove(place.id),
                  ),
                );
              },
            ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    CustomBottomSheet.show(
      context,
      title: 'Add a saved place',
      child: _AddPlaceForm(ref: ref),
    );
  }
}

class _AddPlaceForm extends StatefulWidget {
  final WidgetRef ref;
  const _AddPlaceForm({required this.ref});

  @override
  State<_AddPlaceForm> createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<_AddPlaceForm> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  String _type = 'other';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Home'),
              selected: _type == 'home',
              onSelected: (_) => setState(() => _type = 'home'),
            ),
            ChoiceChip(
              label: const Text('Work'),
              selected: _type == 'work',
              onSelected: (_) => setState(() => _type = 'work'),
            ),
            ChoiceChip(
              label: const Text('Other'),
              selected: _type == 'other',
              onSelected: (_) => setState(() => _type = 'other'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(controller: _labelController, label: 'Label', hint: 'e.g. My apartment'),
        const SizedBox(height: 12),
        AppTextField(controller: _addressController, label: 'Address', hint: 'Search or type an address'),
        const SizedBox(height: 20),
        TaxiPrimaryButton(label: 'Save place', isLoading: _saving, onPressed: _save),
      ],
    );
  }

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty || _addressController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final locations = await locationFromAddress(_addressController.text.trim());
      if (locations.isEmpty) throw Exception('Address not found');
      final loc = locations.first;
      await widget.ref.read(savedPlacesProvider.notifier).add(
            label: _labelController.text.trim(),
            address: _addressController.text.trim(),
            lat: loc.latitude,
            lng: loc.longitude,
            type: _type,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve that address')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
