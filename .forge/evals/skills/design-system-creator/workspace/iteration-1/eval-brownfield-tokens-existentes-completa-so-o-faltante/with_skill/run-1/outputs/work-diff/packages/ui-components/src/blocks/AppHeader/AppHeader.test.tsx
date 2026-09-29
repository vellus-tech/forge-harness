import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../test/axe.js';
import { AppHeader } from './AppHeader.js';

describe('AppHeader', () => {
  it('saúda o usuário pelo nome', () => {
    render(<AppHeader name="Ana" />);
    expect(screen.getByText('Olá, Ana')).toBeInTheDocument();
  });

  it('dispara onNotificationsClick', async () => {
    const onNotificationsClick = vi.fn();
    render(<AppHeader name="Ana" onNotificationsClick={onNotificationsClick} />);
    await userEvent.click(screen.getByRole('button', { name: 'Notificações' }));
    expect(onNotificationsClick).toHaveBeenCalledOnce();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<AppHeader name="Ana" />);
    await runA11y(container);
  });
});
