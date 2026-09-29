import { Card } from '../primitives/Card.js';
import { Button } from '../primitives/Button.js';

export type BalanceCardProps = {
  balance: string;
  passName: string;
  onRechargeClick?: () => void;
};

/** Cartão de saldo do passe com CTA de recarga. */
export function BalanceCard({ balance, passName, onRechargeClick }: BalanceCardProps) {
  return (
    <Card eyebrow="Saldo do passe" className="balance-card">
      <h2>{balance}</h2>
      <small>{passName}</small>
      <div>
        <Button variant="primary" size="sm" onClick={onRechargeClick}>
          Recarregar
        </Button>
      </div>
    </Card>
  );
}
