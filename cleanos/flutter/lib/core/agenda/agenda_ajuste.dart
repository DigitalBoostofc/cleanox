/// agenda_ajuste.dart — Núcleo PURO do AJUSTE por sheet (Fase 3: APK e web
/// estreita). Sem Flutter: só aritmética em **minutos-BRT inteiros** (gate G-8).
///
/// No celular não há grade nem arraste (R4/D3): a OS se ajusta por um bottom
/// sheet com steppers de ±15 min. Só DOIS números mudam — início e duração — e
/// as regras deles moram aqui, compartilhadas com o arraste do desktop:
/// - snap de [kSnapMin] (o mesmo do form e da grade);
/// - **piso de 00:00**: adiantar nunca rola pro dia anterior (D7). O sheet não
///   troca de dia; quem precisa disso reusa [clampDiaDestino];
/// - duração mínima de 15 min e teto na meia-noite ([duracaoValida]).
library;

import 'agenda_drag.dart';
import 'agenda_layout.dart';

/// Novo início após [passos] toques de ±[kSnapMin] no stepper.
///
/// Normaliza pro grid de 15 (uma OS antiga pode começar às 08:07) e nunca sai do
/// relógio do dia: piso 00:00 (D7 — não rola pro dia anterior), teto 23:45.
int inicioComPasso(int startMin, int passos) =>
    snap15(startMin + passos * kSnapMin);

/// Nova duração após [passos] toques de ±[kSnapMin], ancorada em [startMin]
/// (o teto é a meia-noite daquele dia). Piso de [kDuracaoMinimaMin].
///
/// Com `passos: 0` serve para **reancorar**: ao empurrar o início pra frente, a
/// duração encolhe até caber no que sobrou do dia.
int duracaoComPasso(int duracaoMin, int passos, {required int startMin}) =>
    duracaoValida(duracaoMin + passos * kSnapMin, startMin: startMin);
