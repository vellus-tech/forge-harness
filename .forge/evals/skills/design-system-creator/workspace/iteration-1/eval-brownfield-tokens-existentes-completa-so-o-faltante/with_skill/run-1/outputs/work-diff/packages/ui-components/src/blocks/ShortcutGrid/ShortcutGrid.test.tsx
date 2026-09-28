import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Wallet, CreditCard } from 'lucide-react';
import { runA11y } from '../../test/axe.js';
import { ShortcutGrid } from './ShortcutGrid.js';

describe('ShortcutGrid', () => {
  it('renderiza um botão por item e dispara onClick', async () => {
    const onClick = vi.fn();
    render(
      <ShortcutGrid
        items={[
          { icon: Wallet, label: 'Recarregar', onClick },
          { icon: CreditCard, label: 'Cartões' },
        ]}
      />,
    );
    expect(screen.getAllByRole('button')).toHaveLength(2);
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(
      <ShortcutGrid items={[{ icon: Wallet, label: 'Recarregar' }]} />,
    );
    await runA11y(container);
  });
});
