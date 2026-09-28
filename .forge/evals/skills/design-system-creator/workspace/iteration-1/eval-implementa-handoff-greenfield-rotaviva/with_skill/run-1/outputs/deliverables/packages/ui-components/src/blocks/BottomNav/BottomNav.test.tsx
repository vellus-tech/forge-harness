import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../../test/axe.js';
import { BottomNav } from './BottomNav.js';

describe('BottomNav', () => {
  it('marca a aba ativa com aria-current', () => {
    render(<BottomNav active="Viagens" />);
    expect(screen.getByRole('link', { name: 'Viagens' })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('link', { name: 'Início' })).not.toHaveAttribute('aria-current');
  });

  it('dispara onNavigate ao clicar numa aba', async () => {
    const onNavigate = vi.fn();
    render(<BottomNav active="Início" onNavigate={onNavigate} />);
    await userEvent.click(screen.getByRole('link', { name: 'Cartões' }));
    expect(onNavigate).toHaveBeenCalledWith('Cartões');
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<BottomNav active="Início" />);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
