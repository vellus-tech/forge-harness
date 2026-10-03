import type { LucideIcon } from 'lucide-react';
import { Icon } from '@rotaviva/icons';
import styles from './ShortcutGrid.module.css';

export interface ShortcutItem {
  icon: LucideIcon;
  label: string;
  onClick?: () => void;
}

export interface ShortcutGridProps {
  items: ShortcutItem[];
}

/** Grade de atalhos (recarregar, cartões, ajuda…). */
export function ShortcutGrid({ items }: ShortcutGridProps) {
  return (
    <nav className={styles.grid} aria-label="Atalhos">
      {items.map((item) => (
        <button key={item.label} type="button" className={styles.item} onClick={item.onClick}>
          <Icon icon={item.icon} size={24} />
          {item.label}
        </button>
      ))}
    </nav>
  );
}
