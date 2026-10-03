import { useState } from 'react';
import { Wallet, CreditCard, CircleHelp } from 'lucide-react';
import { AppHeader } from '../blocks/AppHeader/AppHeader.js';
import { BalanceCard } from '../blocks/BalanceCard/BalanceCard.js';
import { ShortcutGrid } from '../blocks/ShortcutGrid/ShortcutGrid.js';
import { TripRow } from '../blocks/TripRow/TripRow.js';
import { BottomNav, type BottomNavTab } from '../blocks/BottomNav/BottomNav.js';

export interface HomeScreenProps {
  onRecharge?: () => void;
}

/** Composição da tela Início — não exportada da API pública, só para Storybook/Padrões. */
export function HomeScreen({ onRecharge }: HomeScreenProps) {
  const [tab, setTab] = useState<BottomNavTab>('Início');
  return (
    <>
      <AppHeader name="Ana" />
      <div style={{ padding: '0 16px', flex: 1, overflowY: 'auto' }}>
        <BalanceCard balance="R$ 42,80" passName="Passe Comum" onRecharge={onRecharge} />
        <ShortcutGrid
          items={[
            { icon: Wallet, label: 'Recarregar', onClick: onRecharge },
            { icon: CreditCard, label: 'Cartões' },
            { icon: CircleHelp, label: 'Ajuda' },
          ]}
        />
        <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" />
          <TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" />
        </ul>
      </div>
      <BottomNav active={tab} onChange={setTab} />
    </>
  );
}
