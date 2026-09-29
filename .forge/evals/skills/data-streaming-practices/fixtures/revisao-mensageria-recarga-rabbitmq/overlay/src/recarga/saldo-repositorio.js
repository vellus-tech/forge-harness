// Repositório de saldo (Postgres). O UPDATE soma o valor ao saldo corrente.
const { pool } = require('../infra/db');

async function creditarSaldo(cartaoTransporteId, valorCentavos) {
  await pool.query(
    'UPDATE saldo_cartao SET saldo_centavos = saldo_centavos + $1 WHERE cartao_transporte_id = $2',
    [valorCentavos, cartaoTransporteId],
  );
}

module.exports = { creditarSaldo };
