import { forwardRef } from 'react';
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

/** Grade de atalhos da home (bloco `ShortcutGrid` do ui_kit). */
export const ShortcutGrid = forwardRef<HTMLElement, ShortcutGridProps>(function ShortcutGrid(
  { items },
  ref,
) {
  return (
    <nav ref={ref} className={styles.grid} aria-label="Atalhos">
      {items.map((item) => (
        <button key={item.label} type="button" className={styles.item} onClick={item.onClick}>
          <Icon icon={item.icon} size={24} />
          {item.label}
        </button>
      ))}
    </nav>
  );
});
