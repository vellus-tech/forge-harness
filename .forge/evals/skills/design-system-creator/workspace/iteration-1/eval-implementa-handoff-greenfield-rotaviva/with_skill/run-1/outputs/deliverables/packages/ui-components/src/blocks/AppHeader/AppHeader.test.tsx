import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../../test/axe.js';
import { AppHeader } from './AppHeader.js';

describe('AppHeader', () => {
  it('exibe a saudação com o nome', () => {
    render(<AppHeader name="Ana" />);
    expect(screen.getByText('Olá, Ana')).toBeInTheDocument();
  });

  it('dispara onNotificationsClick', async () => {
    const onClick = vi.fn();
    render(<AppHeader name="Ana" onNotificationsClick={onClick} />);
    await userEvent.click(screen.getByRole('button', { name: 'Notificações' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<AppHeader name="Ana" />);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
