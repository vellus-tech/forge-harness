import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../test/axe.js';
import { BottomNav } from './BottomNav.js';

describe('BottomNav', () => {
  it('marca a aba ativa com aria-current', () => {
    render(<BottomNav active="Viagens" />);
    expect(screen.getByRole('button', { name: 'Viagens' })).toHaveAttribute(
      'aria-current',
      'page',
    );
    expect(screen.getByRole('button', { name: 'Início' })).not.toHaveAttribute('aria-current');
  });

  it('dispara onChange com a aba clicada', async () => {
    const onChange = vi.fn();
    render(<BottomNav active="Início" onChange={onChange} />);
    await userEvent.click(screen.getByRole('button', { name: 'Cartões' }));
    expect(onChange).toHaveBeenCalledWith('Cartões');
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<BottomNav active="Início" />);
    await runA11y(container);
  });
});
