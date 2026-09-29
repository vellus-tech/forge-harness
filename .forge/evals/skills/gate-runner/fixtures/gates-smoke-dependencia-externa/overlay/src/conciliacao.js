// Concilia o extrato de liquidação da adquirente com as transações de bilhetagem.
export function conciliar(transacoes, extrato) {
  const porNsu = new Map(extrato.map((e) => [e.nsu, e]));
  return transacoes.map((t) => {
    const liquidada = porNsu.get(t.nsu);
    if (!liquidada) return { nsu: t.nsu, status: 'pendente' };
    const divergente = Math.abs(liquidada.valor - t.valor) > 0.009;
    return { nsu: t.nsu, status: divergente ? 'divergente' : 'conciliada' };
  });
}
