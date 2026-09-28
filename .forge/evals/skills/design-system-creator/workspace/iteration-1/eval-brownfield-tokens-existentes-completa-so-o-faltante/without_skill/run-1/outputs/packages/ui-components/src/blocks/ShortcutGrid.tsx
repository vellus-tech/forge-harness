import type { ReactNode } from 'react';

export type ShortcutItem = {
  key: string;
  icon: ReactNode;
  label: string;
  onClick?: () => void;
};

export type ShortcutGridProps = {
  items: ShortcutItem[];
};

/** Grade de atalhos da Home (recarregar, cartões, ajuda, ...). */
export function ShortcutGrid({ items }: ShortcutGridProps) {
  return (
    <nav className="shortcut-grid" aria-label="Atalhos">
      {items.map((item) => (
        <button key={item.key} onClick={item.onClick}>
          <span className="icon" aria-hidden="true">
            {item.icon}
          </span>
          {item.label}
        </button>
      ))}
    </nav>
  );
}
