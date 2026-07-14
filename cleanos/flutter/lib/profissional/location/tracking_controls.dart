/// tracking_controls.dart — Controles de tracking na OS ativa (Slice B4).
///
/// Só é montado quando `Env.trackingEnabled` (ver `MapaScreen`). Une o aviso
/// "estou a caminho" (WhatsApp) ao início do tracking GPS, e o "Cheguei ao local"
/// (encerra o tracking + rota /cheguei). Degrada com elegância: permissão negada →
/// esconde o tracking automático e mantém só o "Cheguei" manual.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/models/ordem_servico.dart';
import '../data/prof_providers.dart';
import '../data/server_error.dart';
import 'location_tracking_service.dart';
import 'tracking_providers.dart';

class TrackingControls extends ConsumerStatefulWidget {
  const TrackingControls({super.key, required this.os});

  final OrdemServico os;

  @override
  ConsumerState<TrackingControls> createState() => _TrackingControlsState();
}

class _TrackingControlsState extends ConsumerState<TrackingControls> {
  bool _busy = false;
  bool _sharing = false;
  bool _permissaoNegada = false;

  LocationTrackingService get _svc => ref.read(locationTrackingServiceProvider);

  @override
  void initState() {
    super.initState();
    _sharing = _svc.trackingOsId == widget.os.id;
  }

  void _toast(String msg, ToastType type) {
    if (mounted) showClxToast(context, msg, type: type);
  }

  Future<void> _aCaminho() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 1) Avisa o cliente pelo WhatsApp (rota custom).
      try {
        final res = await ref
            .read(whatsappRepositoryProvider)
            .avisarACaminho(widget.os.id);
        _toast(
          res.ok
              ? 'Cliente avisado pela OS Fácil ✓'
              : 'Não foi possível avisar o cliente.',
          res.ok ? ToastType.success : ToastType.warning,
        );
      } catch (err) {
        // 409 do backend traz `{error}` útil (ex.: WhatsApp desconectado).
        _toast(serverErrorMessage(err), ToastType.warning);
      }

      // 2) Inicia o tracking GPS (foreground service).
      final res = await _svc.start(widget.os.id);
      if (!mounted) return;
      setState(() {
        _sharing = res == TrackingStartResult.iniciado;
        _permissaoNegada = res == TrackingStartResult.permissaoNegada;
      });
      switch (res) {
        case TrackingStartResult.iniciado:
          _toast('Compartilhando sua localização.', ToastType.success);
        case TrackingStartResult.permissaoNegada:
          _toast(
            'Localização negada — use "Cheguei" quando chegar.',
            ToastType.warning,
          );
        case TrackingStartResult.gpsDesligado:
          _toast(
            'Ative o GPS para compartilhar a localização.',
            ToastType.warning,
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cheguei() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _svc.chegou();
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _permissaoNegada = false;
      });
      _toast('Chegada registrada.', ToastType.success);
    } catch (_) {
      _toast('Não foi possível registrar a chegada.', ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tt = Theme.of(context).textTheme;

    if (_sharing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ClxSpace.x3),
            decoration: BoxDecoration(
              color: clx.successBg,
              borderRadius: ClxRadii.rMd,
              border: Border.all(color: clx.success.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location_rounded, size: 16, color: clx.success),
                const SizedBox(width: ClxSpace.x2),
                Expanded(
                  child: Text(
                    'Compartilhando sua localização com o cliente.',
                    style: tt.bodyMedium?.copyWith(
                      color: clx.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ClxSpace.x2),
          ClxButton(
            label: 'Cheguei ao local',
            icon: Icons.flag_outlined,
            expand: true,
            loading: _busy,
            onPressed: _cheguei,
          ),
        ],
      );
    }

    if (_permissaoNegada) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Localização negada — o tracking automático está desligado.',
            style: tt.bodyMedium?.copyWith(color: clx.ink3),
          ),
          const SizedBox(height: ClxSpace.x2),
          ClxButton(
            label: 'Cheguei ao local',
            variant: ClxButtonVariant.secondary,
            icon: Icons.flag_outlined,
            expand: true,
            loading: _busy,
            onPressed: _cheguei,
          ),
        ],
      );
    }

    return ClxButton(
      label: 'Estou a caminho',
      icon: Icons.near_me_rounded,
      expand: true,
      loading: _busy,
      onPressed: _aCaminho,
    );
  }
}
