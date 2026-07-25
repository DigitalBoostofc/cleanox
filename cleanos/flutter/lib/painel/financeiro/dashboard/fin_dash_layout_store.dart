/// fin_dash_layout_store.dart — Persistência do layout freeform **por usuário**.
///
/// Usa SharedPreferences (localStorage no Web) com chave `fin_dash_layout_<userId>`.
/// Sem migration PB — cada browser/dispositivo guarda o layout do login atual.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'fin_dash_layout.dart';

String _key(String userId) => 'fin_dash_layout_$userId';

/// Carrega layout do usuário ou o default.
Future<FinDashLayout> loadFinDashLayout(String userId) async {
  if (userId.isEmpty) return FinDashLayout.defaultLayout();
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return FinDashLayout.defaultLayout();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return FinDashLayout.fromJson(decoded);
    }
    if (decoded is Map) {
      return FinDashLayout.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {
    /* corrompido → default */
  }
  return FinDashLayout.defaultLayout();
}

/// Persiste o layout do usuário (best-effort).
Future<void> saveFinDashLayout(String userId, FinDashLayout layout) async {
  if (userId.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(layout.toJson()));
  } catch (_) {
    /* ignore */
  }
}

/// Apaga preferência (volta ao default no próximo load).
Future<void> clearFinDashLayout(String userId) async {
  if (userId.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  } catch (_) {
    /* ignore */
  }
}
