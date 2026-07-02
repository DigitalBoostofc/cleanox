# 09 — App do Profissional em Flutter + Rastreamento "estou a caminho" (GPS ao vivo)

> **Status: IMPLEMENTAÇÃO FUTURA — não construído.** Documento de planejamento para uma evolução pós-MVP. Decisões tomadas com o dono (2026-06-27): app **Flutter nativo só do profissional**, **Android + iOS**, ETA via **Google Maps**, **GPS ao vivo**. Reverte parcialmente o ADR-003 (que escolheu "PWA único, sem app nativo") apenas para a superfície do profissional.

## 1. Objetivo
Transformar o acesso do profissional num **app nativo (Flutter)** que fala com o **mesmo backend PocketBase**, viabilizando **GPS em segundo plano confiável** e **push nativo**. Com isso, ao tocar "estou a caminho", o sistema mede o tempo de deslocamento até o cliente e avisa o cliente pela marca (anti-desvio preservado):
- **Msg1** (já existe hoje): "Olá {nome}! Aqui é da Cleanox. Nosso profissional está a caminho para o serviço de {servico}."
- **Msg2** (~5 min restantes): "+5 minutos para o profissional chegar."
- **Msg3** (<1 min): "Está quase chegando, falta menos de 1 min. Por favor fique atento."
- Botão **"Cheguei ao local"** → dispara a mensagem de chegada.

O painel (admin/gerente) **continua sendo o PWA React**. Só o profissional migra.

## 2. Viabilidade — pontos críticos
- **Backend não muda de paradigma:** PocketBase já é a API (REST/realtime + regras + rotas custom). Flutter usa o SDK Dart `pocketbase` (pub.dev). **Anti-desvio segue imposto no servidor** — cliente nativo não o enfraquece.
- **iOS exige macOS/Xcode.** A máquina de dev é Linux → Android compila localmente, mas **iOS precisa de um Mac OU CI em nuvem** (Codemagic / GitHub Actions macOS / Bitrise) + **conta Apple Developer ($99/ano)**. Certificados/signing e a conta Apple são **gates do dono**. Android: Play Console ($25 único) ou APK direto.
- **GPS em background:** Android = foreground service + `ACCESS_BACKGROUND_LOCATION` + notificação persistente; iOS = background mode "location" + permissão "Always" + strings no Info.plist (Apple revisa o uso). Throttle de envio (~20–30s / por movimento) por bateria/dados.
- **Push (FCM/APNs):** projeto Firebase (google-services.json / GoogleService-Info.plist) + chave APNs no Firebase; server key FCM no backend.
- **Manutenção:** passa a ter 2ª stack (Dart/Flutter) além de React + PocketBase.
- **Coexistência:** manter as rotas `/app` do PWA React como **fallback web** enquanto o Flutter é o cliente principal; aposentar depois, se quiser.

## 3. Backend (`cleanos/pb`) — adições (servem ao Flutter; reaproveitam o existente)
- **Migração** (`17xxxxxxxx_tracking_push.js`):
  - `ordens_servico`: `prof_lat`, `prof_lng`, `prof_pos_em`, `dest_lat`, `dest_lng`, `aviso_5min_em`, `aviso_1min_em`, `cheguei_em`. Adicionar todos ao `locked` em `os_logic.js:guardOrdemUpdateRequest` (só rotas dedicadas escrevem, server-side).
  - `app_config`: `aviso_5min_texto`, `aviso_1min_texto`, `aviso_cheguei_texto` (defaults com os textos acima).
  - Coleção `push_tokens` (por profissional): `usuario` (relation), `token` (FCM), `plataforma`, `updated`. Regra: profissional cria/atualiza o próprio; admin lê.
- **Helper Google** (`pb_hooks/maps.js`): `geocode(endereco)`→{lat,lng}; `etaMinutes(oLat,oLng,dLat,dLng)`→min (Distance Matrix c/ trânsito). Lê `GOOGLE_MAPS_API_KEY` de env (padrão `$http.send`, igual `uazapi.js`).
- **Rotas** (em `whatsapp_routes.pb.js`, espelhando a `/a-caminho` atual — auth profissional dono + `em_andamento`, telefone só server-side):
  - `POST /api/cleanos/os/{id}/posicao` `{lat,lng}` → grava posição; 1ª vez geocodifica o endereço do cofre → `dest_lat/lng`. Resposta `{ok}`.
  - `POST /api/cleanos/os/{id}/cheguei` → envia `aviso_cheguei_texto`, grava `cheguei_em`, encerra rastreamento.
  - Estender `/a-caminho`: geocodifica destino (se faltar) + reseta `aviso_5min_em/aviso_1min_em/cheguei_em`.
  - `POST /api/cleanos/push/register` `{token,plataforma}` → upsert em `push_tokens`.
- **Cron** (`main.pb.js`, ao lado de `cleanStaleEndereco`): `cronAdd("trackingAvisos","* * * * *",…)` — varre OS `em_andamento` com `aviso_a_caminho_em` setado, sem `cheguei_em`, com `prof_pos_em` recente e `dest_lat/lng`; calcula ETA; dispara Msg2 (≤5min) e Msg3 (≤1min) idempotentes (`aviso_5min_em`/`aviso_1min_em`) via `uazapi.sendText`. Thresholds como constantes + janela máx.
- **Push hook**: ao atribuir OS a um profissional, enviar FCM "Nova OS" para os `push_tokens` dele (`FCM_SERVER_KEY` em env).
- **Config de templates** (`ratings_routes.pb.js` `/whatsapp/config`): incluir os 3 textos novos (editáveis no painel WhatsApp do React).
- **Anti-desvio/limpeza**: o hook que limpa `endereco_liberado` ao sair de `em_andamento` passa a limpar `dest_lat/lng` e `prof_lat/lng` (coords efêmeras). Atualizar `verify_rules.sh`/`anti-desvio.test.mjs`: profissional não grava os novos campos via PATCH; coords somem ao concluir; `push_tokens` isolado.
- **Env** (`/opt/cleanos/cleanos.env`, server-side): `GOOGLE_MAPS_API_KEY`, `FCM_SERVER_KEY`. Documentar no README + `cleanos.env.example`.

## 4. App Flutter (novo — sugestão `cleanos/app_profissional/`)
- Projeto Flutter (Android + iOS). Pacotes: `pocketbase`, `geolocator` + background (`flutter_background_geolocation` ou `flutter_foreground_task`+geolocator), `firebase_messaging`+`firebase_core`, `flutter_secure_storage`, `url_launcher`, `intl`.
- **Auth**: `pb.collection('users').authWithPassword` (papel profissional); token em secure storage; auto-refresh.
- **Telas (paridade com o `/app` React atual):** Login; Meus serviços (visão-de-job: nome_curto, tipo, **bairro**, horário, status, valor — NUNCA telefone); detalhe/ações da OS (Iniciar → libera endereço; "Ver rota" → `url_launcher`/Google Maps; "estou a caminho" → inicia rastreamento + Msg1; "Cheguei ao local"; Registrar pagamento; Concluir); Mapa; Perfil (média + trocar senha + liberar localização). Marca: paleta petrol+cyan, tipografia, claro/escuro, PT-BR.
- **GPS em background**: ao entrar em "em rota", inicia serviço de localização (foreground service Android / background iOS) e envia `POST /os/{id}/posicao` mesmo no fundo. Para ao Cheguei/Concluir. Degradar com aviso se permissão negada (Cheguei manual segue).
- **Push**: registrar device token via `/push/register`; tratar "Nova OS atribuída".
- **Anti-desvio no cliente**: só consome a visão-de-job + rotas dedicadas; NUNCA busca `clientes`; telefone nunca aparece; endereço só durante `em_andamento`.

## 5. Build / distribuição (Android + iOS)
- **Firebase**: criar projeto, `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) + chave APNs. [gate do dono]
- **Android** (compila no Linux): keystore, build AAB/APK; Play (teste interno, $25) ou APK direto.
- **iOS** (PRECISA macOS/Xcode): conta Apple Developer ($99/ano), bundle id, provisioning + capabilities (Background Modes: location, Push), build via Xcode/TestFlight ou CI macOS em nuvem. [gate do dono: conta Apple + certificados]
- Observação: workers de dev em Linux conseguem scaffold + telas + lógica + **build Android**; **build/sign iOS exige Mac/CI** do dono.

## 6. Verificação (quando implementar)
1. Backend local + `GOOGLE_MAPS_API_KEY`/`FCM_SERVER_KEY`; `verify_rules.sh` 21/21 + suíte (novos casos de tracking/push/anti-desvio).
2. Flutter Android: login profissional; OS sem telefone; Iniciar → endereço liberado; "estou a caminho" → `posicao` gravando + `dest_lat/lng` geocodificado.
3. Background GPS: simular trajeto (mock locations) com app no fundo → cron dispara Msg2 (≤5min) e Msg3 (≤1min) uma vez cada; "Cheguei" → Msg de chegada + `cheguei_em` + encerra rastreamento.
4. Push: nova OS ao profissional → push chega.
5. Concluir → coords/posição limpas. iOS: validar no Mac/CI + TestFlight com a conta Apple pronta.
6. Painel React (admin) inalterado; editar os 3 textos na página WhatsApp.

## 7. Fora de escopo / futuro
- Mapa ao vivo da posição pro CLIENTE (acompanhamento visual) — por ora só mensagens.
- "Tempo de deslocamento médio" histórico por profissional/rota.
- Aposentar de vez as rotas `/app` do PWA React.
