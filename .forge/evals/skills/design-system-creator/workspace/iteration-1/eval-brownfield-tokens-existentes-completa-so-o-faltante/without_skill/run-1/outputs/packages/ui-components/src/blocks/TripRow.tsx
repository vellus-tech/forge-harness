import { Bus } from '@rotaviva/icons';
import { Badge, type BadgeTone } from '../primitives/Badge.js';

export type TripRowProps = {
  line: string;
  when: string;
  amount: string;
  status: BadgeTone;
  statusLabel: string;
};

/** Linha de viagem no extrato: linha, quando, valor e status (badge). */
export function TripRow({ line, when, amount, status, statusLabel }: TripRowProps) {
  return (
    <li className="trip-row">
      <span className="icon" aria-hidden="true">
        <Bus size={20} />
      </span>
      <div>
        <strong>Linha {line}</strong>
        <small>{when}</small>
      </div>
      <span>{amount}</span>
      <Badge tone={status}>{statusLabel}</Badge>
    </li>
  );
}
