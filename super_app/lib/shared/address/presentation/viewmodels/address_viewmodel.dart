import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/modules/food/api/datasources/address_remote_datasource.dart';
import 'package:superapp_user/shared/address/data/address_model.dart';
import 'package:superapp_user/shared/address/application/address_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

/// Saved addresses, backed by `/food/user/addresses`.
///
/// Guests hold an empty list — the endpoint is Bearer-only — and the list
/// reloads automatically when the user logs in or out.
final addressViewModelProvider =
    NotifierProvider<AddressViewModel, List<AddressModel>>(
      AddressViewModel.new,
    );

class AddressViewModel extends Notifier<List<AddressModel>> {
  AddressRemoteDataSource get _remote =>
      ref.read(addressRemoteDataSourceProvider);

  bool isLoading = false;
  String? error;

  @override
  List<AddressModel> build() {
    // Reload whenever the session changes.
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        if (next.value == null) {
          state = const [];
        } else {
          unawaited(load());
        }
      }
    });

    if (ref.read(authViewModelProvider).value != null) {
      unawaited(load());
    }
    return const [];
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    try {
      state = await _remote.getAddresses();
    } catch (e) {
      // Keep the last-known-good list on a transient failure (e.g. a
      // timeout) instead of wiping it to empty — that previously made
      // checkout wrongly think the user had no saved address at all.
      error = _messageOf(e);
      _log('load() failed: $e');
    } finally {
      isLoading = false;
    }
  }

  Future<bool> addAddress(AddressModel address) async {
    try {
      final created = await _remote.addAddress(address);
      state = [...state, created];
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('addAddress() failed: $e');
      return false;
    }
  }

  Future<bool> editAddress(AddressModel address) async {
    try {
      final updated = await _remote.updateAddress(address);
      state = [for (final a in state) a.id == updated.id ? updated : a];
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('editAddress() failed: $e');
      return false;
    }
  }

  Future<bool> deleteAddress(String id) async {
    try {
      await _remote.deleteAddress(id);
      state = state.where((a) => a.id != id).toList();
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('deleteAddress() failed: $e');
      return false;
    }
  }

  Future<bool> setDefaultAddress(String id) async {
    try {
      await _remote.setDefault(id);
      // The server clears the flag on the previous default, so mirror that
      // locally instead of trusting only the returned row.
      state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('setDefaultAddress() failed: $e');
      return false;
    }
  }

  String _messageOf(Object e) =>
      e is Failure ? e.message : 'Something went wrong. Please try again.';

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'Address');
  }

  AddressModel? get defaultAddress {
    for (final a in state) {
      if (a.isDefault) return a;
    }
    return state.isEmpty ? null : state.first;
  }
}
