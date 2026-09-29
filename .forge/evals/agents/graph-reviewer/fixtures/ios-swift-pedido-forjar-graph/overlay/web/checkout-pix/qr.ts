import { formatarValor } from './formatar';
export function renderQr(payload: string, centavos: number): string { return `<div data-pix="${payload}">${formatarValor(centavos)}</div>`; }
