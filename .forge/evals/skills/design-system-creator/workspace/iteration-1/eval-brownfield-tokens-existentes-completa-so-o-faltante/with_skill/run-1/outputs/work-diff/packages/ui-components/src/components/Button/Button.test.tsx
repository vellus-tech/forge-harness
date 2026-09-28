import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../test/axe.js';
import { Button } from './Button.js';

describe('Button', () => {
  it('renderiza o texto e responde a clique', async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Recarregar</Button>);
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('não dispara clique quando disabled', async () => {
    const onClick = vi.fn();
    render(
      <Button disabled onClick={onClick}>
        Recarregar
      </Button>,
    );
    await userEvent.click(screen.getByRole('button', { name: 'Recarregar' }));
    expect(onClick).not.toHaveBeenCalled();
  });

  it('não tem violações de acessibilidade (primary e danger)', async () => {
    const { container } = render(
      <>
        <Button variant="primary">Recarregar</Button>
        <Button variant="danger">Bloquear cartão</Button>
      </>,
    );
    await runA11y(container);
  });
});
