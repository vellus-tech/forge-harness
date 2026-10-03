export interface Clock { agora(): Date }
export const relogioSistema: Clock = { agora: () => new Date() };
