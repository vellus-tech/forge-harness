const TABS = ['Início', 'Viagens', 'Cartões', 'Perfil'] as const;

export type BottomNavTab = (typeof TABS)[number];

export type BottomNavProps = {
  active: BottomNavTab;
  onNavigate?: (tab: BottomNavTab) => void;
};

/** Navegação inferior com 4 abas fixas; aba ativa marcada com aria-current="page". */
export function BottomNav({ active, onNavigate }: BottomNavProps) {
  return (
    <nav className="bottom-nav" aria-label="Navegação principal">
      {TABS.map((tab) => (
        <a
          key={tab}
          role="link"
          tabIndex={0}
          aria-current={tab === active ? 'page' : undefined}
          onClick={() => onNavigate?.(tab)}
        >
          {tab}
        </a>
      ))}
    </nav>
  );
}
