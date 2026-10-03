import { forwardRef } from 'react';
import { Home, Route, CreditCard, User } from 'lucide-react';
import { Icon } from '@rotaviva/icons';
import styles from './BottomNav.module.css';

const TABS = [
  { label: 'Início', icon: Home },
  { label: 'Viagens', icon: Route },
  { label: 'Cartões', icon: CreditCard },
  { label: 'Perfil', icon: User },
] as const;

export type BottomNavTab = (typeof TABS)[number]['label'];

export interface BottomNavProps {
  active: BottomNavTab;
  onChange?: (tab: BottomNavTab) => void;
}

/** Navegação inferior de 4 abas (bloco `BottomNav` do ui_kit). */
export const BottomNav = forwardRef<HTMLElement, BottomNavProps>(function BottomNav(
  { active, onChange },
  ref,
) {
  return (
    <nav ref={ref} className={styles.nav} aria-label="Navegação principal">
      {TABS.map((tab) => {
        const isActive = tab.label === active;
        return (
          <button
            key={tab.label}
            type="button"
            className={styles.tab}
            aria-current={isActive ? 'page' : undefined}
            onClick={() => onChange?.(tab.label)}
          >
            <Icon icon={tab.icon} size={20} className={isActive ? styles.activeIcon : undefined} />
            {tab.label}
          </button>
        );
      })}
    </nav>
  );
});
