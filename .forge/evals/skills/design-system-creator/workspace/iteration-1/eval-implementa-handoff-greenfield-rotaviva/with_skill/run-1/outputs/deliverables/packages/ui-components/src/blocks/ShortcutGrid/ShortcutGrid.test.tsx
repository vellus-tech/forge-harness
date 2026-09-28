import { describe, it, expect, vi } from 'vitest';
import { Wallet, CreditCard, CircleHelp } from 'lucide-react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../../test/axe.js';
import { ShortcutGrid } from './ShortcutGrid.js';

const items = [
  { icon: Wallet, label: 'Recarregar' },
  { icon: CreditCard, label: 'Cartões' },
  { icon: CircleHelp, label: 'Ajuda' },
];

describe('ShortcutGrid', () => {
  it('renderiza um botão por atalho', () => {
    render(<ShortcutGrid items={items} />);
    expect(screen.getAllByRole('button')).toHaveLength(3);
  });

  it('dispara onClick do atalho', async () => {
    const onClick = vi.fn();
    render(<ShortcutGrid items={[{ icon: Wallet, label: 'Recarregar', onClick }]} />);
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<ShortcutGrid items={items} />);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
