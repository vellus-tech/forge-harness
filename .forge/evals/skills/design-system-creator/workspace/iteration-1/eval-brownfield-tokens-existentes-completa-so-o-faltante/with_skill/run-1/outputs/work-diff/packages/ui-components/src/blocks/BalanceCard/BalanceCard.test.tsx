import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../test/axe.js';
import { BalanceCard } from './BalanceCard.js';

describe('BalanceCard', () => {
  it('mostra saldo e nome do passe', () => {
    render(<BalanceCard balance="R$ 42,80" passName="Passe Comum" />);
    expect(screen.getByText('R$ 42,80')).toBeInTheDocument();
    expect(screen.getByText('Passe Comum')).toBeInTheDocument();
  });

  it('dispara onRecharge ao clicar em Recarregar', async () => {
    const onRecharge = vi.fn();
    render(<BalanceCard balance="R$ 42,80" passName="Passe Comum" onRecharge={onRecharge} />);
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onRecharge).toHaveBeenCalledOnce();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<BalanceCard balance="R$ 42,80" passName="Passe Comum" />);
    await runA11y(container);
  });
});
