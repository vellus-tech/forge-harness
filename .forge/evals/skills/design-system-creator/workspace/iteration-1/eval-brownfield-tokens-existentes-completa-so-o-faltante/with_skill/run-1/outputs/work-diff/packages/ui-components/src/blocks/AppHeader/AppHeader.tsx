import { forwardRef } from 'react';
import type { HTMLAttributes } from 'react';
import { Bell } from 'lucide-react';
import { Icon } from '@rotaviva/icons';
import { RotavivaMark } from '@rotaviva/icons';
import { cn } from '../../lib/cn.js';
import styles from './AppHeader.module.css';

export interface AppHeaderProps extends HTMLAttributes<HTMLElement> {
  name: string;
  onNotificationsClick?: () => void;
}

/** Cabeçalho do app: mark + saudação + botão de notificações (bloco `AppHeader` do ui_kit). */
export const AppHeader = forwardRef<HTMLElement, AppHeaderProps>(function AppHeader(
  { name, onNotificationsClick, className, ...rest },
  ref,
) {
  return (
    <header ref={ref} className={cn(styles.header, className)} {...rest}>
      <RotavivaMark size={28} />
      <span className={styles.greeting}>Olá, {name}</span>
      <button
        type="button"
        className={styles.notif}
        aria-label="Notificações"
        onClick={onNotificationsClick}
      >
        <Icon icon={Bell} size={20} />
      </button>
    </header>
  );
});
