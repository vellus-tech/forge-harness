import styles from './BottomNav.module.css';

const TABS = ['Início', 'Viagens', 'Cartões', 'Perfil'] as const;

export interface BottomNavProps {
  active: (typeof TABS)[number];
  onNavigate?: (tab: (typeof TABS)[number]) => void;
}

/** Navegação inferior fixa do app. */
export function BottomNav({ active, onNavigate }: BottomNavProps) {
  return (
    <nav className={styles.nav} aria-label="Navegação principal">
      {TABS.map((tab) => (
        <a
          key={tab}
          href={`#${tab.toLowerCase()}`}
          className={styles.link}
          aria-current={tab === active ? 'page' : undefined}
          onClick={(event) => {
            event.preventDefault();
            onNavigate?.(tab);
          }}
        >
          {tab}
        </a>
      ))}
    </nav>
  );
}
