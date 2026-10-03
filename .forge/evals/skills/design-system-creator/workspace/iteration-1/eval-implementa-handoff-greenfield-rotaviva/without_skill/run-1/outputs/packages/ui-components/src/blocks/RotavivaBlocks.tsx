import type { ReactNode } from "react";
import { Button } from "../primitives/Button";
import { Badge, type BadgeStatus } from "../primitives/Badge";
import { Card } from "../primitives/Card";
import rotavivaMarkTeal from "../assets/brand/rotaviva-mark-teal.png";
import "./blocks.css";

// Blocos do app Rotaviva — porte 1:1 de ui_kits/rotaviva-app/RotavivaComponents.jsx para
// primitivos reais (Button/Badge/Card) + tokens, em vez das classes soltas do JSX de referência.
//
// NOTA (sem cobertura no handoff): os nomes de ícone ("bell", "bus", "wallet", ...) vêm como
// strings no JSX de referência — não há um kit de ícones no bundle. Renderizamos um placeholder
// textual (`data-icon`) e documentamos em docs/product/design-system/components.md a decisão
// pendente de qual lib de ícones adotar (ex.: lucide-react) antes de produção.

function IconPlaceholder({ name }: { name: string }) {
  return (
    <span aria-hidden="true" data-icon={name} className="icon-placeholder">
      {name}
    </span>
  );
}

export interface AppHeaderProps {
  name: string;
}

// SKILL.md do handoff: nunca desenhar o símbolo Rotaviva em SVG — sempre os PNGs de assets/brand/.
export function AppHeader({ name }: AppHeaderProps) {
  return (
    <header className="app-header">
      <img src={rotavivaMarkTeal} alt="Rotaviva" />
      <span>Olá, {name}</span>
      <button aria-label="Notificações" type="button">
        <IconPlaceholder name="bell" />
      </button>
    </header>
  );
}

export interface BalanceCardProps {
  balance: string;
  passName: string;
  onRecharge?: () => void;
}

export function BalanceCard({ balance, passName, onRecharge }: BalanceCardProps) {
  return (
    <Card eyebrow="Saldo do passe">
      <div className="balance-card">
        <h2>{balance}</h2>
        <small>{passName}</small>
        <div>
          <Button variant="primary" size="sm" onClick={onRecharge}>
            Recarregar
          </Button>
        </div>
      </div>
    </Card>
  );
}

export interface TripRowProps {
  line: string;
  when: string;
  amount: string;
  status: BadgeStatus;
}

export function TripRow({ line, when, amount, status }: TripRowProps) {
  return (
    <li className="trip-row">
      <IconPlaceholder name="bus" />
      <div>
        <strong>Linha {line}</strong>
        <small>{when}</small>
      </div>
      <span>{amount}</span>
      <Badge status={status}>{status}</Badge>
    </li>
  );
}

export interface ShortcutItem {
  icon: string;
  label: string;
}

export interface ShortcutGridProps {
  items: ShortcutItem[];
}

export function ShortcutGrid({ items }: ShortcutGridProps) {
  return (
    <nav className="shortcut-grid" aria-label="Atalhos">
      {items.map((item) => (
        <button key={item.label} type="button">
          <IconPlaceholder name={item.icon} />
          {item.label}
        </button>
      ))}
    </nav>
  );
}

export interface BottomNavProps {
  active: "Início" | "Viagens" | "Cartões" | "Perfil";
}

const NAV_ITEMS: BottomNavProps["active"][] = ["Início", "Viagens", "Cartões", "Perfil"];

export function BottomNav({ active }: BottomNavProps) {
  return (
    <nav className="bottom-nav" aria-label="Navegação principal">
      {NAV_ITEMS.map((item) => (
        <a key={item} aria-current={item === active ? "page" : undefined} tabIndex={0}>
          {item}
        </a>
      ))}
    </nav>
  );
}

export type { ReactNode };
