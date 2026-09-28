// Porta do domínio: o domínio declara, a infraestrutura implementa (ver PgCobrancaRepository).
// Nos testes, o domínio recebe um fake em memória (test/fakes.ts).
export interface Cobranca {
  id: string;
  valorCentavos: number;
  status: "aberta" | "paga" | "cancelada";
}

export interface CobrancaRepository {
  buscar(id: string): Promise<Cobranca | null>;
  marcarPaga(id: string): Promise<void>;
}
