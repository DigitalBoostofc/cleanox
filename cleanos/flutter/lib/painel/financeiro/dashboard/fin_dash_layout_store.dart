/// fin_dash_layout_store.dart — Persistência do layout freeform **por usuário**.
///
/// 1. **PocketBase** `users.fin_dash_layout` (JSON) — sync multi-dispositivo
/// 2. **SharedPreferences** (localStorage no Web) — cache offline / paint rápido
///
/// Save: grava local na hora; PB com debounce (gestos de drag não spamam a API).
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/pb/pb_client.dart';
import 'fin_dash_layout.dart';

String _key(String userId) => 'fin_dash_layout_$userId';

Timer? _pbSaveTimer;
String? _pbSaveUserId;
Map<String, dynamic>? _pbSavePayload;

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {
      /* ignore */
    }
  }
  return null;
}

bool _hasLayoutPayload(Map<String, dynamic>? m) {
  if (m == null || m.isEmpty) return false;
  final items = m['items'];
  return items is List && items.isNotEmpty;
}

FinDashLayout _fromMap(Map<String, dynamic>? m) {
  if (!_hasLayoutPayload(m)) return FinDashLayout.defaultLayout();
  return FinDashLayout.fromJson(m);
}

Future<void> _cacheLocal(String userId, Map<String, dynamic> json) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(json));
  } catch (_) {
    /* ignore */
  }
}

Future<Map<String, dynamic>?> _readLocal(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    return _asMap(raw);
  } catch (_) {
    return null;
  }
}

/// Cache local só (paint instantâneo no open do dashboard).
Future<FinDashLayout?> loadFinDashLayoutLocal(String userId) async {
  if (userId.isEmpty) return null;
  final local = await _readLocal(userId);
  if (!_hasLayoutPayload(local)) return null;
  return _fromMap(local);
}

/// Lê o JSON do record via getOne.
Future<Map<String, dynamic>?> _readFromPb(String userId) async {
  try {
    final pb = PbClient.instance.pb;
    if (!pb.authStore.isValid) return null;
    final authId = pb.authStore.record?.id;
    if (authId == null || authId != userId) return null;

    final rec = await pb.collection('users').getOne(userId);
    final j = rec.toJson();
    return _asMap(j['fin_dash_layout']);
  } catch (_) {
    return null;
  }
}

Future<void> _writeToPb(String userId, Map<String, dynamic> json) async {
  try {
    final pb = PbClient.instance.pb;
    if (!pb.authStore.isValid) return;
    final authId = pb.authStore.record?.id;
    if (authId == null || authId != userId) return;
    await pb.collection('users').update(
      userId,
      body: <String, dynamic>{'fin_dash_layout': json},
    );
  } catch (_) {
    /* offline / campo ainda não migrado — cache local permanece */
  }
}

void _schedulePbSave(String userId, Map<String, dynamic> json) {
  _pbSaveUserId = userId;
  _pbSavePayload = json;
  _pbSaveTimer?.cancel();
  _pbSaveTimer = Timer(const Duration(milliseconds: 700), () {
    final uid = _pbSaveUserId;
    final payload = _pbSavePayload;
    _pbSaveUserId = null;
    _pbSavePayload = null;
    if (uid == null || payload == null) return;
    unawaited(_writeToPb(uid, payload));
  });
}

/// Flush imediato do save PB pendente (ex.: ao sair de "Editar layout").
Future<void> flushFinDashLayoutSave() async {
  _pbSaveTimer?.cancel();
  _pbSaveTimer = null;
  final uid = _pbSaveUserId;
  final payload = _pbSavePayload;
  _pbSaveUserId = null;
  _pbSavePayload = null;
  if (uid != null && payload != null) {
    await _writeToPb(uid, payload);
  }
}

/// Carrega layout: PB → cache local → default.
/// Se PB tiver layout e local diferir, atualiza o cache local.
/// Se só local tiver, agenda upload para a conta.
Future<FinDashLayout> loadFinDashLayout(String userId) async {
  if (userId.isEmpty) return FinDashLayout.defaultLayout();

  final remote = await _readFromPb(userId);
  if (_hasLayoutPayload(remote)) {
    await _cacheLocal(userId, remote!);
    return _fromMap(remote);
  }

  final local = await _readLocal(userId);
  if (_hasLayoutPayload(local)) {
    // Sobe cache local para o PB (migração browser → conta).
    _schedulePbSave(userId, local!);
    return _fromMap(local);
  }

  return FinDashLayout.defaultLayout();
}

/// Persistência completa (local + agenda PB).
Future<void> saveFinDashLayout(String userId, FinDashLayout layout) async {
  if (userId.isEmpty) return;
  final json = layout.toJson();
  await _cacheLocal(userId, json);
  _schedulePbSave(userId, json);
}

/// Apaga preferência (local + PB) e volta ao default.
Future<void> clearFinDashLayout(String userId) async {
  if (userId.isEmpty) return;
  _pbSaveTimer?.cancel();
  _pbSaveTimer = null;
  _pbSaveUserId = null;
  _pbSavePayload = null;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  } catch (_) {
    /* ignore */
  }
  try {
    final pb = PbClient.instance.pb;
    if (!pb.authStore.isValid) return;
    final authId = pb.authStore.record?.id;
    if (authId == null || authId != userId) return;
    await pb.collection('users').update(
      userId,
      body: <String, dynamic>{'fin_dash_layout': <String, dynamic>{}},
    );
  } catch (_) {
    /* ignore */
  }
}
