# Release Android — App Profissional (Flutter) → Google Play

Checklist do **dono** para colocar o app do profissional (`lib/main_profissional.dart`)
na Google Play. Escopo: **somente Android**. iOS depende de Mac + conta Apple e está
fora deste pipeline.

- **applicationId / package:** `br.com.wenox.cleanos`
- **Entrypoint:** `lib/main_profissional.dart`
- **Workflow:** `.github/workflows/android-release-profissional.yml`
- **Signing config:** `cleanos/flutter/android/app/build.gradle.kts` (lê de `android/key.properties`)

> Enquanto os secrets abaixo **não** estiverem configurados, o pipeline **continua
> funcionando**: ele builda um `.aab`/`.apk` com assinatura de debug e sobe como
> artifact do Actions (baixável), mas **não publica** na Play. Nada quebra.

---

## 1. Criar o upload keystore (uma única vez)

Rode **na sua máquina** (precisa do `keytool`, que vem com o JDK). **Nunca** comite
este arquivo — ele fica só na sua máquina e dentro dos GitHub Secrets.

```sh
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storepass 'SENHA_FORTE_AQUI' \
  -keypass  'SENHA_FORTE_AQUI' \
  -dname "CN=Wenox, OU=CleanOS, O=Wenox, L=Cidade, S=Estado, C=BR"
```

Guarde `upload-keystore.jks` e a senha num cofre (1Password/Bitwarden). **Se perder,
não dá pra atualizar o app** (recuperação só via Play App Signing, leva 1–2 dias).

Gere a versão base64 (é o que vai no Secret):

```sh
base64 -w0 upload-keystore.jks > upload-keystore.b64   # Linux
# macOS: base64 -i upload-keystore.jks -o upload-keystore.b64
```

---

## 2. Adicionar os GitHub Secrets

Em **GitHub → repositório → Settings → Secrets and variables → Actions → New repository secret**.
Nomes **exatos** (o workflow depende deles):

| Secret | Conteúdo |
|---|---|
| `KEYSTORE_FILE` | conteúdo de `upload-keystore.b64` (o base64 do `.jks`) |
| `KEYSTORE_PASSWORD` | a senha do keystore (`-storepass`) |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | a senha da chave (`-keypass`; normalmente igual à do keystore) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON inteiro da service account (passo 4) |

Via CLI (alternativa):

```sh
gh secret set KEYSTORE_FILE     < upload-keystore.b64
gh secret set KEYSTORE_PASSWORD --body 'SENHA_FORTE_AQUI'
gh secret set KEY_ALIAS         --body 'upload'
gh secret set KEY_PASSWORD      --body 'SENHA_FORTE_AQUI'
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < service-account.json
```

> Sem `KEYSTORE_FILE` → build cai no debug-signing (não publica).
> Sem `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` → build assina, sobe artifact, mas não publica.

---

## 3. Criar o app no Play Console ($25, uma vez)

1. [Google Play Console](https://play.google.com/console) → pague a taxa única de **US$ 25**.
2. **Create app** → nome, idioma (pt-BR), tipo **App**, **Free/Paid**.
3. Preencha o mínimo de ficha (Data safety, Content rating, Target audience, Privacy policy).
4. **Habilite Play App Signing** (padrão em apps novos): o Google guarda a chave de
   assinatura final; você só administra o *upload key* do passo 1.
5. **Primeiro upload manual obrigatório:** a API do Play só publica depois que **pelo
   menos um `.aab` foi enviado manualmente**. Baixe o artifact `app-profissional-*` de
   uma execução do workflow (ou builde local com `flutter build appbundle --release -t
   lib/main_profissional.dart`) e suba na faixa **Internal testing** pela UI uma vez.

---

## 4. Criar a service account (publicação automática)

1. [Google Cloud Console](https://console.cloud.google.com) → mesmo projeto/organização.
2. **IAM & Admin → Service Accounts → Create service account** → nome `github-play-publisher` → **Done** (sem roles).
3. Abra a conta → aba **Keys → Add key → Create new key → JSON** → baixe. Esse JSON é o `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
4. **APIs & Services** → habilite **Google Play Android Developer API**.
5. Volte no **Play Console → Users and permissions → Invite new user** → e-mail
   `github-play-publisher@SEU-PROJETO.iam.gserviceaccount.com` → permissões:
   - ✅ Release apps to testing tracks
   - ✅ Manage testing tracks and edit testers
   - ✅ (para produção) Release to production
   → **Apply**.

---

## 5. Como acionar cada stage

| Ação | Comando | Faixa Play |
|---|---|---|
| Publicar em teste interno | `git push origin main` (só se algo em `cleanos/flutter/**` mudou) | `internal` |
| Alpha (teste fechado) | `git tag v1.0.0-alpha && git push origin v1.0.0-alpha` | `alpha` |
| Beta (teste aberto) | `git tag v1.0.0-beta && git push origin v1.0.0-beta` | `beta` |
| **Produção** | `git tag v1.0.0 && git push origin v1.0.0` | `production` (rollout **20%**) |
| Manual (qualquer faixa) | GitHub → **Actions → Android Release (Profissional) → Run workflow** → escolha a faixa | escolhida |

### Auto-bump do build number

Todo push em `main` que toca `cleanos/flutter/**` incrementa automaticamente o `+N` do
`version:` no `pubspec.yaml` (ex. `1.0.0+1` → `1.0.0+2`), commita com `[skip ci]` e faz
push de volta. **Você não precisa** mexer nisso para o teste interno.

### Antes de uma tag (alpha/beta/produção)

Tags **não** têm auto-bump (representam um commit fixo). Suba o `versionName` (e o `+N`
se quiser) manualmente antes de taggear:

```sh
# edite pubspec.yaml: version: 1.1.0+5
git commit -am "chore: bump para 1.1.0+5"
git tag v1.1.0
git push origin main --tags
```

### Rollout de produção

O padrão de produção é **staged rollout de 20%** (`status: inProgress`, `userFraction: 0.2`).
Para liberar 100%, avance o rollout na UI do Play Console, ou edite o passo
**Resolve rollout status** no workflow (`fraction=1.0` / `status=completed`).

---

## 6. Segurança — o que NUNCA é commitado

- `*.jks` / `*.keystore` e `android/key.properties` estão no `.gitignore` (checado).
- Senhas e o JSON da service account vivem só nos **GitHub Secrets**.
- No CI, `android/key.properties` e o `.jks` são escritos em tempo de build a partir
  dos secrets e **apagados no fim do job** (step *Clean up signing material*, `if: always()`).

---

## 7. O que fica bloqueado até o dono prover

1. **Conta Play Console ($25)** + primeiro upload manual do `.aab`.
2. **Upload keystore** (passo 1) + os 4 secrets `KEYSTORE_*`.
3. **Service account JSON** (passo 4) + convite no Play Console + `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

Sem (2) o build usa debug-signing; sem (3) não publica. Com os três, o pipeline
publica sozinho conforme a tabela do passo 5.
