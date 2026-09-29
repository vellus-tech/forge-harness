import { AppHeader, BalanceCard, TripRow, ShortcutGrid, BottomNav } from './RotavivaComponents.jsx';
export function HomeScreen() {
  return <main><AppHeader name="Ana" /><BalanceCard balance="R$ 42,80" passName="Passe Comum" />
    <ShortcutGrid items={[{ icon: 'wallet', label: 'Recarregar' }, { icon: 'credit-card', label: 'Cartões' }, { icon: 'circle-help', label: 'Ajuda' }]} />
    <ul><TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" /><TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" /></ul>
    <BottomNav active="Início" /></main>;
}
export function RechargeScreen() {
  return <main><h1>Recarregar passe</h1><label>Valor da recarga<input placeholder="R$ 0,00" /></label><button className="btn primary">Confirmar recarga</button></main>;
}
