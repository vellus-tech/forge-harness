import { Bell } from '@rotaviva/icons';
import { Button } from '../primitives/Button.js';

export type AppHeaderProps = {
  name: string;
  onNotificationsClick?: () => void;
};

/**
 * Cabeçalho do app: marca (PNG oficial — nunca redesenhar em SVG, ver
 * design-handoff/rotaviva-design-system/project/SKILL.md), saudação e sino de notificações.
 */
export function AppHeader({ name, onNotificationsClick }: AppHeaderProps) {
  return (
    <header className="app-header">
      <img src="/brand/rotaviva-mark-teal.png" alt="Rotaviva" />
      <span>Olá, {name}</span>
      <Button
        variant="ghost"
        size="sm"
        className="icon-only"
        aria-label="Notificações"
        onClick={onNotificationsClick}
      >
        <Bell size={20} />
      </Button>
    </header>
  );
}
