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

const STATUS_LABEL: Record<BadgeStatus, string> = {
  success: 'Aprovada',
  warning: 'Pendente',
  neutral: 'Expirada',
};

/** Linha de viagem no extrato — ícone, linha, horário, valor e status. */
export function TripRow({ line, when, amount, status }: TripRowProps) {
  return (
    <li className={styles.row}>
      <span className={styles.icon}>
        <Icon icon={Bus} size={20} />
      </span>
      <div className={styles.info}>
        <strong className={styles.line}>Linha {line}</strong>
        <small className={styles.when}>{when}</small>
      </div>
      <span className={styles.amount}>{amount}</span>
      <Badge status={status}>{STATUS_LABEL[status]}</Badge>
    </li>
  );
}
