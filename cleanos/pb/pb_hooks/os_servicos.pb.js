/// <reference path="../pb_data/types.d.ts" />

/**
 * CleanOS — hooks do épico Serviços/OS (snapshot imutável + evidências).
 *
 * Arquivo COMPLEMENTAR a main.pb.js (não substitui nada nele). PocketBase
 * encadeia todos os handlers registrados para um mesmo evento/coleção; cada um
 * chama e.next(). A ordem entre arquivos não importa aqui: estes handlers são
 * independentes dos de main.pb.js (denormalização, endereço efêmero, etc.).
 *
 * A lógica pesada mora em os_logic.js e é importada DENTRO de cada handler,
 * pois cada hook roda numa VM isolada (mesmo padrão de main.pb.js).
 *
 * Cobre:
 *   - RISCO #2 (defesa em profundidade): congela service_snapshot no servidor a
 *     partir do registro `servicos`, sem nunca sobrescrever um snapshot existente.
 *   - RISCO #5: força os_evidencias.enviado_por = autor autenticado quando vazio,
 *     e reforça que o profissional só anexa evidência a OS dele.
 */

// ----------------------------------------------------------------------------
// ORDENS DE SERVIÇO — snapshot imutável do serviço (modelo, sempre roda)
// ----------------------------------------------------------------------------
// Roda em QUALQUER caminho de gravação (API, seed, admin UI) → o snapshot é
// preenchido de forma consistente mesmo que a UI não o envie. Roda em nível de
// MODELO (e não de request) DEPOIS do guard de request, então não colide com a
// trava de campo `service_snapshot` da denylist do profissional: no momento do
// guard o usuário não alterou o snapshot; quem o escreve é o servidor, aqui.
onRecordCreate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.fillServiceSnapshot(e.app, e.record);
  e.next();
}, "ordens_servico");

onRecordUpdate((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  lib.fillServiceSnapshot(e.app, e.record); // só preenche se ainda estiver vazio
  e.next();
}, "ordens_servico");

// ----------------------------------------------------------------------------
// OS_EVIDENCIAS — request: força o autor e reforça a posse da OS.
// ----------------------------------------------------------------------------
// RISCO #5: `enviado_por` é defensivamente fixado no autor autenticado quando
// vier vazio (a UI também seta). Reforço opcional: se o autor é profissional,
// garante que a OS referenciada é dele (a createRule EVID_OWNER já cobre isso;
// este check é defesa em profundidade).
onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/os_logic.js`);
  const relId = lib.relId;
  const auth = e.auth;

  if (auth && auth.id) {
    const role = String(auth.get("role"));

    // SA-MÉDIO: profissional NÃO pode forjar autoria — o servidor SOBRESCREVE
    // sempre `enviado_por` com o id autenticado (antes só preenchia quando vazio,
    // o que era spoofável via FormData). admin/gerente podem registrar evidência
    // em nome de outro autor, então para eles mantemos "só preenche se ausente".
    if (role === "profissional") {
      e.record.set("enviado_por", auth.id);
    } else if (!relId(e.record.get("enviado_por"))) {
      e.record.set("enviado_por", auth.id);
    }

    // reforço: profissional só anexa evidência a OS atribuída a ele.
    if (role === "profissional") {
      const osId = relId(e.record.get("os"));
      if (osId) {
        let os = null;
        try {
          os = e.app.findRecordById("ordens_servico", osId);
        } catch (_) {
          os = null; // OS inexistente → deixa a createRule/validação nativa decidir
        }
        if (os && relId(os.get("profissional")) !== String(auth.id)) {
          throw new ForbiddenError(
            "Você não pode anexar evidência a uma OS que não é sua."
          );
        }
      }
    }
  }

  e.next();
}, "os_evidencias");
