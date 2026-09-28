import { Bell } from 'lucide-react';
import { Icon } from '@rotaviva/icons';
import { RotavivaMark } from '@rotaviva/icons';
import styles from './AppHeader.module.css';

export interface AppHeaderProps {
  name: string;
  onNotificationsClick?: () => void;
}

/** Cabeçalho do app: mark + saudação + botão de notificações. */
export function AppHeader({ name, onNotificationsClick }: AppHeaderProps) {
  return (
    <header className={styles.header}>
      <RotavivaMark variant="teal" className={styles.mark} />
      <span className={styles.greeting}>Olá, {name}</span>
      <button
        type="button"
        className={styles.bell}
        aria-label="Notificações"
        onClick={onNotificationsClick}
      >
        <Icon icon={Bell} size={24} />
      </button>
    </header>
  );
}
