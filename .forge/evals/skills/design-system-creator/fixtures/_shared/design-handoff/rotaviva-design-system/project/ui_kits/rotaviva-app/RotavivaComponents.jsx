// Blocos do app Rotaviva (referência de anatomia — não é código de produção)
export function AppHeader({ name }) {
  return <header className="app-header"><img src="../../assets/brand/rotaviva-mark-teal.png" alt="" /><span>Olá, {name}</span><button aria-label="Notificações">bell</button></header>;
}
export function BalanceCard({ balance, passName }) {
  return <section className="card"><span className="eyebrow">Saldo do passe</span><h2>{balance}</h2><small>{passName}</small><button className="btn primary sm">Recarregar</button></section>;
}
export function TripRow({ line, when, amount, status }) {
  return <li className="trip-row"><span className="icon">bus</span><div><strong>Linha {line}</strong><small>{when}</small></div><span>{amount}</span><span className={`badge ${status}`}>{status}</span></li>;
}
export function ShortcutGrid({ items }) {
  return <nav className="shortcut-grid">{items.map((i) => <button key={i.label}><span className="icon">{i.icon}</span>{i.label}</button>)}</nav>;
}
export function BottomNav({ active }) {
  return <nav className="bottom-nav">{['Início', 'Viagens', 'Cartões', 'Perfil'].map((t) => <a key={t} aria-current={t === active ? 'page' : undefined}>{t}</a>)}</nav>;
}
