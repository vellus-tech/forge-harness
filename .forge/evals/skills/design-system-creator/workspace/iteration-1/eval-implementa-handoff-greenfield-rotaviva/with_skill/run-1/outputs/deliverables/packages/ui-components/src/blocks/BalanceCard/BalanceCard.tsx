import { Card } from '../../components/Card/Card.js';
import { Eyebrow } from '../../components/Eyebrow/Eyebrow.js';
import { Button } from '../../components/Button/Button.js';
import styles from './BalanceCard.module.css';

export interface BalanceCardProps {
  balance: string;
  passName: string;
  onRecharge?: () => void;
}

/** Card de saldo do passe com atalho de recarga. */
export function BalanceCard({ balance, passName, onRecharge }: BalanceCardProps) {
  return (
    <Card>
      <Eyebrow>Saldo do passe</Eyebrow>
      <p className={styles.balance}>{balance}</p>
      <small className={styles.passName}>{passName}</small>
      <Button variant="primary" size="sm" onClick={onRecharge}>
        Recarregar
      </Button>
    </Card>
  );
}
