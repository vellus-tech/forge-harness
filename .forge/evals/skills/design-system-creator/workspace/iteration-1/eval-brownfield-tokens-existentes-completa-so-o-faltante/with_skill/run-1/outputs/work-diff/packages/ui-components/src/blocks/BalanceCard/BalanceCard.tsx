import { forwardRef } from 'react';
import { Card } from '../../components/Card/Card.js';
import { Eyebrow } from '../../components/Eyebrow/Eyebrow.js';
import { Button } from '../../components/Button/Button.js';
import styles from './BalanceCard.module.css';

export interface BalanceCardProps {
  balance: string;
  passName: string;
  onRecharge?: () => void;
}

/** Card de saldo do passe + CTA de recarga (bloco `BalanceCard` do ui_kit). */
export const BalanceCard = forwardRef<HTMLDivElement, BalanceCardProps>(function BalanceCard(
  { balance, passName, onRecharge },
  ref,
) {
  return (
    <Card ref={ref} className={styles.card}>
      <Eyebrow>Saldo do passe</Eyebrow>
      <h2 className={styles.balance}>{balance}</h2>
      <small className={styles.passName}>{passName}</small>
      <Button variant="primary" size="sm" onClick={onRecharge}>
        Recarregar
      </Button>
    </Card>
  );
});
