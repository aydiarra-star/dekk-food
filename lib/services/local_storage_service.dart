import 'package:shared_preferences/shared_preferences.dart';

/// Petite couche de persistance qui isole SharedPreferences du reste de
/// l'application. Si le stockage n'est pas disponible (mode privé, par
/// exemple), l'application continue de fonctionner en mémoire.
class LocalStorageService {
  LocalStorageService._(this._preferences);

  final SharedPreferences? _preferences;

  static Future<LocalStorageService> create() async {
    try {
      return LocalStorageService._(await SharedPreferences.getInstance());
    } catch (_) {
      return LocalStorageService._(null);
    }
  }

  String? readString(String key) => _preferences?.getString(key);

  bool readBool(String key, {required bool fallback}) =>
      _preferences?.getBool(key) ?? fallback;

  List<String> readStringList(String key) =>
      List<String>.unmodifiable(_preferences?.getStringList(key) ?? const []);

  Future<void> writeString(String key, String value) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setString(key, value);
    } catch (_) {
      // L'état en mémoire reste utilisable si l'écriture locale échoue.
    }
  }

  Future<void> writeBool(String key, bool value) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setBool(key, value);
    } catch (_) {
      // Voir le commentaire dans writeString.
    }
  }

  Future<void> writeStringList(String key, Iterable<String> values) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setStringList(key, values.toList(growable: false));
    } catch (_) {
      // Voir le commentaire dans writeString.
    }
  }

  Future<void> remove(String key) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.remove(key);
    } catch (_) {
      // Voir le commentaire dans writeString.
    }
  }
}
