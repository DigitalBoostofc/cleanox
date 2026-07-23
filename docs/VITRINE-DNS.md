# DNS + deploy — agendar.cleanox.com.br

## Arquitetura na VPS

| Camada | Detalhe |
|--------|---------|
| DNS | Cloudflare (NS: gwen / konnor) |
| IP VPS | `181.215.134.11` |
| Host público | **`https://agendar.cleanox.com.br`** |
| Traefik | `/etc/easypanel/traefik/config/cleanox-vitrine.yaml` |
| SPA | Docker `cleanos-vitrine-web` → host `:4052` → `/opt/cleanos/vitrine/web` |
| API | Mesmo PocketBase `http://172.18.0.1:8090` (`PathPrefix(/api)`) |

## Passo 1 — Cloudflare (você / dono)

No painel **Cloudflare → domínio cleanox.com.br → DNS → Add record**:

| Campo | Valor |
|-------|--------|
| Type | **A** |
| Name | **agendar** |
| IPv4 | **181.215.134.11** |
| Proxy status | **DNS only** (nuvem cinza) — recomendado p/ Let's Encrypt |
| TTL | Auto |

Salvar. Propagação costuma ser **1–5 min** (às vezes até 1 h).

Se você já criou `vitrine`, pode **apagar** esse registro e criar só o `agendar`.

Conferir:

```bash
dig +short agendar.cleanox.com.br A
# deve retornar: 181.215.134.11
```

> Se deixar Proxy laranja (CDN), o certificado LE do Traefik pode falhar. Prefira **DNS only** no início.

## Passo 2 — Já feito na VPS

- [x] Build Flutter `main_vitrine.dart` em `/opt/cleanos/vitrine/web`
- [x] Nginx Alpine na porta **4052**
- [x] Traefik `cleanox-vitrine.yaml` com Host `agendar.cleanox.com.br` (HTTP→HTTPS, API→PB, SPA→4052)

## Passo 3 — Validar depois do DNS

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://agendar.cleanox.com.br/
curl -sS https://agendar.cleanox.com.br/api/cleanos/vitrine/servicos | head -c 200
```

Esperado: `200` no HTML e JSON com `items` de serviços.

## Redeploy da vitrine (após mudanças Flutter)

```bash
cd cleanos/flutter
flutter build web --release -t lib/main_vitrine.dart
rsync -az --delete build/web/ hostinger:/opt/cleanos/vitrine/web/
# nginx já monta o volume; sem restart
```

## Rollback Traefik

```bash
ssh hostinger 'rm /etc/easypanel/traefik/config/cleanox-vitrine.yaml'
# file provider recarrega sozinho
```
