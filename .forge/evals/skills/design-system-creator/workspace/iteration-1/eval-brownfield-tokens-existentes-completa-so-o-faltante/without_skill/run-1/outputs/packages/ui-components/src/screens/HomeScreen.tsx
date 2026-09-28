import { Wallet, CreditCard, CircleHelp } from '@rotaviva/icons';
import { AppHeader } from '../blocks/AppHeader.js';
import { BalanceCard } from '../blocks/BalanceCard.js';
import { ShortcutGrid } from '../blocks/ShortcutGrid.js';
import { TripRow } from '../blocks/TripRow.js';
import { BottomNav } from '../blocks/BottomNav.js';

export type HomeScreenProps = {
  userName: string;
  balance: string;
  passName: string;
  onRechargeClick?: () => void;
};

/** Tela inicial: header + saldo + atalhos + últimas viagens + nav inferior. */
export function HomeScreen({ userName, balance, passName, onRechargeClick }: HomeScreenProps) {
  return (
    <main className="screen">
      <AppHeader name={userName} />
      <BalanceCard balance={balance} passName={passName} onRechargeClick={onRechargeClick} />
      <ShortcutGrid
        items={[
          { key: 'recarregar', icon: <Wallet size={20} />, label: 'Recarregar', onClick: onRechargeClick },
          { key: 'cartoes', icon: <CreditCard size={20} />, label: 'Cartões' },
          { key: 'ajuda', icon: <CircleHelp size={20} />, label: 'Ajuda' },
        ]}
      />
      <ul className="trip-list">
        <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" statusLabel="Aprovada" />
        <TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" statusLabel="Pendente" />
      </ul>
      <BottomNav active="Início" />
    </main>
  );
}
