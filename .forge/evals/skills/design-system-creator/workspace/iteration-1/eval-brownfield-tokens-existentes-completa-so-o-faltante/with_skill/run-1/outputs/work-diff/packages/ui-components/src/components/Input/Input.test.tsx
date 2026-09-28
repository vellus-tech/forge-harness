import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { runA11y } from '../../test/axe.js';
import { Input } from './Input.js';

describe('Input', () => {
  it('associa label, hint e aceita digitação', async () => {
    render(<Input label="Valor da recarga" hint="Mínimo R$ 5,00" />);
    const input = screen.getByLabelText('Valor da recarga');
    await userEvent.type(input, '10');
    expect(input).toHaveValue('10');
    expect(screen.getByText('Mínimo R$ 5,00')).toBeInTheDocument();
  });

  it('marca aria-invalid e mostra a mensagem de erro', () => {
    render(<Input label="Valor da recarga" error="Valor mínimo é R$ 5,00" />);
    expect(screen.getByLabelText('Valor da recarga')).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByText('Valor mínimo é R$ 5,00')).toBeInTheDocument();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<Input label="Valor da recarga" hint="Mínimo R$ 5,00" />);
    await runA11y(container);
  });
});
