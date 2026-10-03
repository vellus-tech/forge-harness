export const BASE_FARE_CENTS = 520;

export function fareFor(passengers) {
  if (!Number.isInteger(passengers) || passengers < 1) throw new RangeError('passengers inválido');
  return passengers * BASE_FARE_CENTS;
}
