/// <reference path="./types.d.ts" />

/**
 * agenda_compromissos — profissional conclui a própria tarefa.
 * Admin/gerente seguem com CRUD livre. Profissional não cria, não apaga
 * e no update só o status passa (demais campos voltam ao original).
 */
onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/agenda_compromissos_lib.js`);
  const auth = e.auth;
  if (!auth) throw new ForbiddenError("Sem permissão.");
  if (e.hasSuperuserAuth && e.hasSuperuserAuth()) {
    e.next();
    return;
  }
  const role = String(auth.get("role") || "");
  const roles = auth.get("roles") || [];
  if (lib.ehCofre(role)) {
    e.next();
    return;
  }
  if (!lib.ehProfissional(role, roles)) {
    throw new ForbiddenError("Sem permissão.");
  }
  const orig = e.record.original ? e.record.original() : null;
  const recordProf = String(
    (orig ? orig.get("profissional") : e.record.get("profissional")) || "",
  );
  const err = lib.validarUpdateProf({
    authId: auth.id,
    recordProfId: recordProf,
    status: e.record.get("status"),
  });
  if (err) throw new ForbiddenError(err);
  if (orig) {
    for (const f of lib.camposTravadosProf()) {
      e.record.set(f, orig.get(f));
    }
  }
  e.next();
}, "agenda_compromissos");
