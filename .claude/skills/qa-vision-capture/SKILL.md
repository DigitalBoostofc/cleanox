---
name: qa-vision-capture
description: Loop de teste visual por screenshots numa janela macOS — shot, click, doubleclick, type e key via helper python (capture.py) parametrizado por nome de processo. Use quando for testar um app como usuário, exclusivamente por visão, no QA Vision Lab.
---

# qa-vision-capture

Você testa um app SÓ por screenshots, com o helper `capture.py` desta skill.

## Setup (uma vez por sessão)

Deps: Quartz (pyobjc) + PIL + `cliclick` (brew). Verifique e instale se faltar:

```bash
python3 -c "import Quartz, PIL" 2>/dev/null || pip3 install pyobjc-framework-Quartz pillow
which cliclick >/dev/null || brew install cliclick
```

Se `pip3 install` falhar por ambiente gerenciado, crie um venv:

```bash
python3 -m venv ~/.qa-vision-venv && ~/.qa-vision-venv/bin/pip install pyobjc-framework-Quartz pillow
# daí use ~/.qa-vision-venv/bin/python3 no lugar de python3
```

Configure o alvo por ENV — NUNCA edite o script pra hardcodar:

```bash
export QA_TARGET_OWNER="Electron"     # nome do PROCESSO da janela-alvo (obrigatório)
export QA_TARGET_TITLE=""             # substring do título, se precisar desambiguar (opcional)
export QA_OUT_DIR="runs/qa"           # onde caem os frames numerados (opcional)
```

Exemplo: app Electron em dev = owner `Electron`; produção Overclock = owner
`Overclock` (NÃO toque na produção se o alvo é o dev).

## Comandos

```bash
python3 <skill-dir>/capture.py shot              # screenshot → imprime path do PNG
python3 <skill-dir>/capture.py click 410 220     # click em coords LÓGICAS do screenshot
python3 <skill-dir>/capture.py doubleclick 410 220
python3 <skill-dir>/capture.py type "texto"
python3 <skill-dir>/capture.py key return        # return|esc|tab|space|delete|arrow-*
```

O screenshot já vem corrigido de retina pra pixels lógicos: a coordenada que
você lê NA IMAGEM é a coordenada que você passa pro click, 1:1. Cada ação tira
um shot novo automaticamente e imprime o path. Frames numerados
(`frame_000123.png`) ficam em `QA_OUT_DIR` como histórico/evidência.

## O loop (disciplina)

1. `shot` → **Read no PNG** (sempre LEIA a imagem antes de agir).
2. Decida UMA ação. Máximo 2 frases de raciocínio por turno — olhe, aja.
3. Execute a ação (o helper já tira o shot pós-ação).
4. Read no novo PNG → compare esperado vs observado.
5. Divergiu → registre o finding no contrato (skill qa-finding-protocol /
   formato do seu briefing) citando o frame de evidência. Volte ao passo 2.

Regras: nunca encadeie ações sem ver o resultado; nunca clique em coordenada
que você não LEU na imagem atual; janela errada no shot = PARE e corrija o
QA_TARGET_OWNER antes de qualquer ação.
