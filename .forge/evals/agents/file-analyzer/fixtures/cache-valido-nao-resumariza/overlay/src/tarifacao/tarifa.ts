import { Money } from '../shared/money';
export type Modal = 'onibus' | 'metro' | 'brt';
export interface Tarifa { linhaId: string; modal: Modal; valor: Money; vigenteDesde: Date; vigenteAte: Date | null }
