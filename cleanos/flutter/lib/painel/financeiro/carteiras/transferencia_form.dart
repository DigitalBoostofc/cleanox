/// transferencia_form.dart — Modal de TRANSFERÊNCIA entre contas (`fin_contas`).
///
/// Espelha o modal de transferência de `ContasCarteiras.tsx`: origem/destino/valor
/// com validação (origem ≠ destino, valor > 0, contas existentes). Chama a rota
/// transacional [FinanceiroPanelRepository.transferir] — débito+crédito na MESMA
/// transação server-side (sem read-then-write nem rollback no cliente). Saldo
/// negativo é PERMITIDO (não bloqueia). Após salvar, o caller REFETCHA as contas
/// (`finContasProvider`) pois a mutação de saldo não emite realtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/models/financeiro.dart';
import '../fin_common.dart';
import '../fin_form_kit.dart';
import '../fin_providers.dart';

/// Abre o modal de transferência. Resolve `true` se a transferência foi feita.
Future<bool?> showTransferenciaForm(BuildContext context) =>
    showFinModal<bool>(context, const TransferenciaForm());

class TransferenciaForm extends ConsumerStatefulWidget {
  const TransferenciaForm({super.key});

  @override
  ConsumerState<TransferenciaForm> createState() => _TransferenciaFormState();
}

class _TransferenciaFormState extends ConsumerState<TransferenciaForm> {
  late final TextEditingController _valor;
  String? _fromId;
  String? _toId;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _valor = TextEditingController();
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  /// Semeia origem/destino com as duas primeiras contas ativas (como o web).
  void _seed(List<FinConta> contas) {
    if (_initialized) return;
    _initialized = true;
    final ativas = contas.where((c) => c.ativo).toList();
    _fromId = ativas.isNotEmpty ? ativas[0].id : null;
    _toId = ativas.length > 1 ? ativas[1].id : null;
  }

  Future<void> _save(List<FinConta> contas) async {
    final errs = <String, String>{};
    if (_fromId == null || _toId == null) {
      errs['contas'] = 'Selecione as contas de origem e destino.';
    } else if (_fromId == _toId) {
      errs['contas'] = 'Origem e destino devem ser diferentes.';
    }
    final valor = parseMoedaBr(_valor.text);
    if (valor == null || valor <= 0) {
      errs['valor'] = 'Informe um valor maior que zero.';
    }
    if (errs.isNotEmpty) {
      setState(() {
        _errs
          ..clear()
          ..addAll(errs);
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _errs.clear();
    });
    try {
      await ref
          .read(financeiroRepositoryProvider)
          .transferir(_fromId!, _toId!, valor!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = finErrorMessage(
            e,
            fallback: 'Não foi possível concluir a transferência.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contas = ref.watch(finContasProvider).valueOrNull ?? const [];
    _seed(contas);

    String label(String id) => contas
        .firstWhere((c) => c.id == id, orElse: () => FinConta(id: id, nome: id))
        .nome;
    String labelComSaldo(String id) {
      final c = contas.firstWhere(
        (c) => c.id == id,
        orElse: () => FinConta(id: id, nome: id),
      );
      return '${c.nome} — ${formatCurrency(c.saldoAtual)}';
    }

    final ids = contas.map((c) => c.id).toList();

    return FinModalScaffold(
      title: 'Transferência entre contas',
      saving: _saving,
      error: _saveError,
      onSave: () => _save(contas),
      saveLabel: 'Transferir',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinDropdown<String>(
            label: 'De',
            required: true,
            value: _fromId,
            enabled: !_saving,
            error: _errs['contas'],
            hint: 'Selecione…',
            items: ids,
            itemLabel: labelComSaldo,
            onChanged: (v) => setState(() {
              _fromId = v;
              _errs.remove('contas');
            }),
          ),
          FinDropdown<String>(
            label: 'Para',
            required: true,
            value: _toId,
            enabled: !_saving,
            hint: 'Selecione…',
            items: ids,
            itemLabel: labelComSaldo,
            onChanged: (v) => setState(() {
              _toId = v;
              _errs.remove('contas');
            }),
          ),
          FinField(
            label: 'Valor',
            controller: _valor,
            required: true,
            enabled: !_saving,
            prefix: 'R\$ ',
            hint: '0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _errs['valor'],
            onChanged: (_) {
              if (_errs.containsKey('valor')) {
                setState(() => _errs.remove('valor'));
              }
            },
          ),
          if (_fromId != null && _toId != null && _fromId != _toId)
            Padding(
              padding: const EdgeInsets.only(top: ClxSpace.x1),
              child: Text(
                'De ${label(_fromId!)} para ${label(_toId!)}.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.clx.ink3),
              ),
            ),
        ],
      ),
    );
  }
}
