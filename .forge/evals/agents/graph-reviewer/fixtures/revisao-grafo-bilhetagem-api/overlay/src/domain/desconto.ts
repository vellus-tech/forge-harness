export type Perfil = 'comum' | 'estudante' | 'idoso';
export function percentualDesconto(p: Perfil): number { return p === 'estudante' ? 50 : p === 'idoso' ? 100 : 0; }
