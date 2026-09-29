import { AppHeader, BalanceCard, ShortcutGrid, TripRow, BottomNav } from "../blocks/RotavivaBlocks";
import "./screens.css";

export interface HomeScreenProps {
  onRecharge?: () => void;
}

// Porte de ui_kits/rotaviva-app/Screens.jsx::HomeScreen — mesmos dados de exemplo do handoff.
export function HomeScreen({ onRecharge }: HomeScreenProps) {
  return (
    <main className="screen">
      <AppHeader name="Ana" />
      <BalanceCard balance="R$ 42,80" passName="Passe Comum" onRecharge={onRecharge} />
      <ShortcutGrid
        items={[
          { icon: "wallet", label: "Recarregar" },
          { icon: "credit-card", label: "Cartões" },
          { icon: "circle-help", label: "Ajuda" },
        ]}
      />
      <ul className="trip-list">
        <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" />
        <TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" />
      </ul>
      <BottomNav active="Início" />
    </main>
  );
}
