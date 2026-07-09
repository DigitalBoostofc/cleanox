# CleanOS (Flutter)

Único frontend do CleanOS: **Flutter Web** (painel) + **Android** (APK unificado por papel).

Backend: PocketBase em `../pb/`. Contrato e regras de domínio: `../../CLAUDE.md` e `../pb/README.md`.

## Superfícies

| Entrypoint | Surface | Uso |
|---|---|---|
| `lib/main_painel.dart` | `AppSurface.painel` | Flutter Web — painel admin/gerente |
| `lib/main_android.dart` | `AppSurface.android` | APK unificado (CI/release) — roteia por `role` |
| `lib/main_profissional.dart` | `AppSurface.profissional` | Dev legado só-profissional |

## Dev

```bash
# Web (painel)
flutter run -d chrome --dart-define=PB_URL=http://127.0.0.1:8090 -t lib/main_painel.dart

# Android (APK unificado)
flutter run -d <DEVICE> --dart-define=PB_URL=http://10.0.2.2:8090 -t lib/main_android.dart
```

## Gate de qualidade (obrigatório antes de PR)

```bash
flutter analyze --fatal-infos
flutter test
```

## Build release

```bash
# Web → deploy em pb_public/
flutter build web --release -t lib/main_painel.dart

# Android (local; CI assina e publica)
flutter build apk --release -t lib/main_android.dart
```

## UI Fintech Clean

- **APK:** tema fintech sempre.
- **Web &lt; 600dp:** mesmo casco/tema fintech do APK (`PainelShell` + `isNarrowWebProvider`).
- **Web ≥ 600dp:** layout clássico desktop (sidebar/rail).

## Estrutura

```
lib/
  core/              models, repos, design, auth, router
  painel/            telas admin
  profissional/      telas do executor
  shared_widgets_os/ checklist, evidências (compartilhado)
  main_*.dart        entrypoints
```
