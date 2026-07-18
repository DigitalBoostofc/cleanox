/// user.dart — Porte de `User` + `Role` de collections.ts (coleção auth `users`).
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'collections.dart';

export 'collections.dart' show Role;

part 'user.freezed.dart';
part 'user.g.dart';

/// Usuário autenticado. `role` decide a superfície (painel vs profissional).
///
/// Default defensivo de papel desconhecido → `profissional` (menor privilégio):
/// jamais elevamos alguém a admin por um valor inesperado do servidor.
@freezed
class User with _$User {
  const factory User({
    required String id,
    @Default('') String name,
    @Default('') String email,
    @JsonKey(unknownEnumValue: Role.profissional)
    @Default(Role.profissional)
    Role role,

    /// Nome de exibição do colaborador (campo extra do CleanOS).
    String? nome,

    /// WhatsApp do PRÓPRIO colaborador (contato, não é PII de cliente). Usado
    /// para o aviso "Nova OS" ao profissional. Cadastrado pelo admin.
    String? whatsapp,

    /// Comissão: `nenhuma` | `percentual` | `fixo` (migration 23).
    @JsonKey(name: 'comissao_tipo', unknownEnumValue: ComissaoTipo.nenhuma)
    @Default(ComissaoTipo.nenhuma)
    ComissaoTipo comissaoTipo,

    /// % (0–100) ou valor fixo em R$, conforme [comissaoTipo].
    @JsonKey(name: 'comissao_valor') @Default(0) double comissaoValor,

    /// Nome do arquivo no storage PB (migration 24). `""` = sem foto.
    @Default('') String avatar,

    /// Cor na agenda (`#RRGGBB`, migration 33). `""` = paleta automática.
    @JsonKey(name: 'cor_agenda') @Default('') String corAgenda,

    @Default(false) bool verified,
    @JsonKey(name: 'emailVisibility') @Default(false) bool emailVisibility,
    String? created,
    String? updated,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  /// Constrói a partir de um RecordModel do SDK PocketBase.
  factory User.fromRecord(RecordModel record) {
    final j = Map<String, dynamic>.from(record.toJson());
    // Campo opcional: PB pode omitir ou mandar "" / null.
    final tipo = j['comissao_tipo'];
    if (tipo == null || tipo == '') j['comissao_tipo'] = 'nenhuma';
    final val = j['comissao_valor'];
    if (val == null || val == '') j['comissao_valor'] = 0;
    if (j['avatar'] == null) j['avatar'] = '';
    if (j['cor_agenda'] == null) j['cor_agenda'] = '';
    return User.fromJson(j);
  }

  /// Nome de exibição: prioriza `nome`, cai para `name`, senão '—'
  /// (espelha `userDisplayName` de collections.ts).
  String get displayName {
    final n = nome?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (name.trim().isNotEmpty) return name;
    return '—';
  }

  bool get hasAvatar => avatar.trim().isNotEmpty;

  /// URL pública do avatar. [baseUrl] = PB_URL sem barra final.
  String? avatarUrl(String baseUrl, {String thumb = '100x100'}) {
    if (!hasAvatar) return null;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final q = thumb.isEmpty ? '' : '?thumb=$thumb';
    return '$base/api/files/users/$id/$avatar$q';
  }

  /// Inicial (1 letra) para fallback visual.
  String get initials {
    final dn = displayName.trim();
    if (dn.isEmpty || dn == '—') return 'U';
    return dn.substring(0, 1).toUpperCase();
  }

  /// Profissional com comissão ativa (aba Financeiro no APK).
  bool get hasComissaoAtiva =>
      role == Role.profissional &&
      comissaoTipo.isAtiva &&
      comissaoValor > 0;

  String get comissaoResumo {
    if (!comissaoTipo.isAtiva || comissaoValor <= 0) return 'Sem comissão';
    if (comissaoTipo == ComissaoTipo.percentual) {
      final v = comissaoValor == comissaoValor.roundToDouble()
          ? comissaoValor.toStringAsFixed(0)
          : comissaoValor.toStringAsFixed(1);
      return '$v% por OS';
    }
    return 'R\$ ${comissaoValor.toStringAsFixed(2)} por OS';
  }
}

/// Nome de exibição a partir de campos soltos (espelha `userDisplayName`).
String userDisplayName({String? nome, String? name}) {
  final n = nome?.trim();
  if (n != null && n.isNotEmpty) return n;
  if (name != null && name.trim().isNotEmpty) return name;
  return '—';
}
