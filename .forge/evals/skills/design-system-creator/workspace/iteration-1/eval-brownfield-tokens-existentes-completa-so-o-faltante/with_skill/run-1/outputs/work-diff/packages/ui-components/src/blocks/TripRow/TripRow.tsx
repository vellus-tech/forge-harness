import { forwardRef } from 'react';
import { Bus } from 'lucide-react';
import { Icon } from '@rotaviva/icons';
import { Badge, type BadgeStatus } from '../../components/Badge/Badge.js';
import styles from './TripRow.module.css';

export interface TripRowProps {
  line: string;
  when: string;
  amount: string;
  status: BadgeStatus;
}

/** Linha do extrato de viagens (bloco `TripRow` do ui_kit). Renderiza como `<li>`. */
export const TripRow = forwardRef<HTMLLIElement, TripRowProps>(function TripRow(
  { line, when, amount, status },
  ref,
) {
  return (
    <li ref={ref} className={styles.row}>
      <Icon icon={Bus} size={20} aria-label={`Linha ${line}`} />
      <div className={styles.info}>
        <strong>Linha {line}</strong>
        <small>{when}</small>
      </div>
      <span className={styles.amount}>{amount}</span>
      <Badge status={status}>{statusLabel[status]}</Badge>
    </li>
  );
});

const statusLabel: Record<BadgeStatus, string> = {
  success: 'Aprovada',
  warning: 'Pendente',
  neutral: 'Expirada',
};
