/**
 * CleanOS — unicidade de telefone em `clientes` (lib).
 *
 * Usada por `clientes_telefone_unique.pb.js`. require() DENTRO do handler (R9).
 */

function findClienteMesmoTelefone(app, telefone, excludeId) {
  const lib = require(`${__hooks}/os_logic.js`);
  const raw = String(telefone || "").trim();
  if (!raw) return null;

  const digits = raw.replace(/\D/g, "");
  // Incompleto: deixa required/min da coleção/UI decidir.
  if (digits.length < 10) return null;

  const limit = 200;
  let offset = 0;
  for (;;) {
    const batch = app.findRecordsByFilter(
      "clientes",
      "id != ''",
      "-created",
      limit,
      offset,
    );
    if (!batch || batch.length === 0) break;

    for (let i = 0; i < batch.length; i++) {
      const rec = batch[i];
      if (excludeId && rec.id === excludeId) continue;
      if (lib.phonesMatch(rec.getString("telefone"), raw)) {
        return rec;
      }
    }

    if (batch.length < limit) break;
    offset += limit;
  }
  return null;
}

function assertTelefoneUnico(app, record) {
  const telefone = record.getString("telefone");
  const existente = findClienteMesmoTelefone(app, telefone, record.id);
  if (!existente) return;

  const nome = [existente.getString("nome"), existente.getString("sobrenome")]
    .filter((s) => s && String(s).trim())
    .join(" ")
    .trim();
  const label = nome || "sem nome";
  throw new BadRequestError(
    "Cliente já existente com este número de celular (" + label + ").",
  );
}

module.exports = {
  findClienteMesmoTelefone,
  assertTelefoneUnico,
};
