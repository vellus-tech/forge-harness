import { Tarifa, tarifaIntegrada } from '../domain/tarifa';
import { Centavos } from '../shared/money';
export function calcularTarifa(t: Tarifa, minutosDesdeUltimoEmbarque: number): Centavos { return tarifaIntegrada(t, minutosDesdeUltimoEmbarque); }
