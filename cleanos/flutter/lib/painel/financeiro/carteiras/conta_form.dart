/// conta_form.dart — Modal de criar/editar uma Conta/Carteira (`fin_contas`).
///
/// Espelha o modal de `ContasCarteiras.tsx`. Na CRIAÇÃO o saldo informado vira
/// `saldo_inicial` E `saldo_atual` (abertura de conta é legítima). Na EDIÇÃO, o
/// campo "Saldo atual = X" tem semântica de SET: quando o usuário muda o valor,
/// chamamos a rota transacional [FinanceiroPanelRepository.definirSaldo] com o
/// valor ABSOLUTO — o servidor lê o saldo FRESCO dentro da transação e aplica o
/// delta necessário, evitando a janela de lost-update de calcular `novo − antigo`
/// no cliente sobre um `antigo` já defasado. O cliente NUNCA grava `saldo_atual`.
/// Após salvar, o caller REFETCHA as contas (`finContasProvider`), pois a mutação
/// de saldo não emite realtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/models/financeiro.dart';
import '../fin_common.dart';
import '../fin_form_kit.dart';
import '../fin_labels.dart';
import '../fin_providers.dart';

/// Abre o form de conta. [editing] nulo = criar. Resolve `true` se salvou.
Future<bool?> showContaForm(BuildContext context, {FinConta? editing}) =>
    showFinModal<bool>(context, ContaForm(editing: editing));

class ContaForm extends ConsumerStatefulWidget {
  const ContaForm({super.key, this.editing});

  final FinConta? editing;

  @override
  ConsumerState<ContaForm> createState() => _ContaFormState();
}

class _ContaFormState extends ConsumerState<ContaForm> {
  late final TextEditingController _nome;
  late final TextEditingController _saldo;
  late ContaTipo _tipo;
  bool _ativo = true;
  String? _cor;

  bool _saving = false;
  String? _saveError;
  final Map<String, String> _errs = {};

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _nome = TextEditingController(text: c?.nome ?? '');
    _saldo = TextEditingController(
      text: c == null ? '' : formatMoedaInput(c.saldoAtual),
    );
    _tipo = c?.tipo ?? ContaTipo.carteira;
    _ativo = c?.ativo ?? true;
    _cor = c?.cor;
  }

  @override
  void dispose() {
    _nome.dispose();
    _saldo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errs = <String, String>{};
    if (_nome.text.trim().isEmpty) errs['nome'] = 'Nome é obrigatório';
    final saldo = parseMoedaBr(_saldo.text);
    if (saldo == null) errs['saldo'] = 'Informe um valor válido';
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
    final repo = ref.read(financeiroRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateConta(widget.editing!.id, {
          'nome': _nome.text.trim(),
          'tipo': _tipo.wire,
          'ativo': _ativo,
          'cor': _cor,
        });
        // O campo é "Saldo atual = X" (semântica de SET, não de incremento).
        // Só mandamos quando o usuário DE FATO mexeu no valor exibido — assim
        // não sobrescrevemos um saldo que outra OS/gerente pode ter mudado desde
        // que o form abriu. Quando muda, [definirSaldo] deixa o servidor ler o
        // saldo FRESCO dentro da transação e converter para delta (sem a janela
        // de lost-update de calcular delta no cliente sobre um saldo defasado).
        if (saldo! != widget.editing!.saldoAtual) {
          await repo.definirSaldo(widget.editing!.id, saldo);
        }
      } else {
        await repo.createConta({
          'nome': _nome.text.trim(),
          'tipo': _tipo.wire,
          'saldo_inicial': saldo,
          'saldo_atual': saldo,
          'ativo': _ativo,
          'cor': _cor,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          // Traduz por código (403 sem permissão, 400 validação, 404 conta…).
          _saveError = finErrorMessage(
            e,
            fallback: _isEdit
                ? 'Não foi possível salvar as alterações.'
                : 'Não foi possível criar a carteira.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return FinModalScaffold(
      title: _isEdit ? 'Editar carteira' : 'Nova carteira',
      saving: _saving,
      error: _saveError,
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinField(
            label: 'Nome',
            controller: _nome,
            required: true,
            enabled: !_saving,
            hint: 'Ex.: Caixa, Nubank, Dinheiro',
            error: _errs['nome'],
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_errs.containsKey('nome')) {
                setState(() => _errs.remove('nome'));
              }
            },
          ),
          FinTwoCol(
            FinDropdown<ContaTipo>(
              label: 'Tipo',
              value: _tipo,
              enabled: !_saving,
              items: ContaTipo.values,
              itemLabel: contaTipoLabel,
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            FinField(
              label: _isEdit ? 'Saldo atual' : 'Saldo inicial',
              controller: _saldo,
              required: true,
              enabled: !_saving,
              prefix: 'R\$ ',
              hint: '0,00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              error: _errs['saldo'],
              onChanged: (_) {
                if (_errs.containsKey('saldo')) {
                  setState(() => _errs.remove('saldo'));
                }
              },
            ),
          ),
          _corPicker(clx),
          const SizedBox(height: ClxSpace.x2),
          Row(
            children: [
              Switch(
                value: _ativo,
                activeThumbColor: clx.primary,
                onChanged: _saving ? null : (v) => setState(() => _ativo = v),
              ),
              const SizedBox(width: ClxSpace.x2),
              Text(
                _ativo ? 'Carteira ativa' : 'Carteira inativa',
                style: TextStyle(color: clx.ink2, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _corPicker(CleanoxColors clx) {
    final cores = clx.finSeries;
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor de destaque',
          style: TextStyle(
            color: clx.ink2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ClxSpace.x2),
        Wrap(
          spacing: ClxSpace.x2,
          runSpacing: ClxSpace.x2,
          children: [
            for (final c in cores)
              _Swatch(
                color: c,
                selected: _cor == hex(c),
                onTap: _saving ? null : () => setState(() => _cor = hex(c)),
              ),
            _Swatch(
              color: clx.ink3,
              icon: Icons.block_rounded,
              selected: _cor == null,
              onTap: _saving ? null : () => setState(() => _cor = null),
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    return InkWell(
      onTap: onTap,
      borderRadius: ClxRadii.rPill,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: icon == null ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? clx.ink : clx.line2,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: icon == null
            ? (selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null)
            : Icon(icon, size: 16, color: clx.ink3),
      ),
    );
  }
}
