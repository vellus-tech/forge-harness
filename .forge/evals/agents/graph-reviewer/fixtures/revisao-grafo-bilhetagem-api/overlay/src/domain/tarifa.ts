import { Centavos } from '../shared/money';
export interface Tarifa { linha: string; valor: Centavos; integracao: boolean; }
export function tarifaIntegrada(t: Tarifa, minutos: number): Centavos { return t.integracao && minutos <= 120 ? 0 : t.valor; }
