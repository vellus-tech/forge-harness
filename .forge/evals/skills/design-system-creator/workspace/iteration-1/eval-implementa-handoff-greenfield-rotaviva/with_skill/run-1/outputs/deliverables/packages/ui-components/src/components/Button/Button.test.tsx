import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../../test/axe.js';
import { Button } from './Button.js';

describe('Button', () => {
  it('renderiza o conteúdo e responde a clique', async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Recarregar</Button>);
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('não dispara clique quando desabilitado', async () => {
    const onClick = vi.fn();
    render(
      <Button onClick={onClick} disabled>
        Recarregar
      </Button>,
    );
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).not.toHaveBeenCalled();
  });

  it.each(['primary', 'secondary', 'ghost', 'danger'] as const)(
    'não tem violações de a11y na variante %s',
    async (variant) => {
      const { container } = render(<Button variant={variant}>Ação</Button>);
      expect(await runA11y(container)).toHaveNoViolations();
    },
  );
});
