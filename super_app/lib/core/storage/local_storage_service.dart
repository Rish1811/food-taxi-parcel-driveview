import 'package:hive_flutter/hive_flutter.dart';
import 'package:superapp_user/core/storage/storage_keys.dart';

class LocalStorageService {
  late Box recentSearches;
  late Box savedAddresses;
  late Box emergencyContacts;
  late Box favoriteDrivers;
  late Box settings;

  Future<void> init() async {
    await Hive.initFlutter();
    recentSearches = await Hive.openBox(StorageKeys.recentSearchesBox);
    savedAddresses = await Hive.openBox(StorageKeys.savedAddressesBox);
    emergencyContacts = await Hive.openBox(StorageKeys.emergencyContactsBox);
    favoriteDrivers = await Hive.openBox(StorageKeys.favoriteDriversBox);
    settings = await Hive.openBox(StorageKeys.settingsBox);
  }
}
