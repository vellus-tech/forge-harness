import { AppHeader } from '../../blocks/AppHeader/AppHeader.js';
import { BalanceCard } from '../../blocks/BalanceCard/BalanceCard.js';
import { ShortcutGrid } from '../../blocks/ShortcutGrid/ShortcutGrid.js';
import { TripRow } from '../../blocks/TripRow/TripRow.js';
import { BottomNav } from '../../blocks/BottomNav/BottomNav.js';
import { Wallet, CreditCard, CircleHelp } from 'lucide-react';
import styles from './HomeScreen.module.css';

export interface HomeScreenProps {
  onRecharge?: () => void;
}

/** Composição da tela inicial — só Storybook, não exportada na API pública. */
export function HomeScreen({ onRecharge }: HomeScreenProps) {
  return (
    <main className={styles.main}>
      <AppHeader name="Ana" />
      <div style={{ padding: '0 var(--s-6)' }}>
        <BalanceCard balance="R$ 42,80" passName="Passe Comum" onRecharge={onRecharge} />
      </div>
      <ShortcutGrid
        items={[
          { icon: Wallet, label: 'Recarregar', onClick: onRecharge },
          { icon: CreditCard, label: 'Cartões' },
          { icon: CircleHelp, label: 'Ajuda' },
        ]}
      />
      <ul className={styles.tripList}>
        <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" />
        <TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" />
      </ul>
      <BottomNav active="Início" />
    </main>
  );
}
