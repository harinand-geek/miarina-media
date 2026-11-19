import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/settings.dart';
import '../library/library_data.dart';

/// Durable settings, stored as JSON in the shared `settings` table of the
/// library database (same storage as the Tauri app).
abstract interface class SettingsStore {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? value);
}

class RustSettingsStore implements SettingsStore {
  RustSettingsStore(this._ref);

  final Ref _ref;

  @override
  Future<Object?> read(String key) async {
    final raw = await settingsGet(
      dbPath: await _ref.read(dbPathProvider.future),
      key: key,
    );
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> write(String key, Object? value) async => settingsSet(
    dbPath: await _ref.read(dbPathProvider.future),
    key: key,
    json: jsonEncode(value),
  );
}

final settingsStoreProvider = Provider<SettingsStore>(RustSettingsStore.new);
