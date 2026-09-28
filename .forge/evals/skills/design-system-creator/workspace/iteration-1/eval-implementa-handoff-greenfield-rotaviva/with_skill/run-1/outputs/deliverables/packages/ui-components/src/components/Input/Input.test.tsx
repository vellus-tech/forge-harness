import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../../test/axe.js';
import { Input } from './Input.js';

describe('Input', () => {
  it('associa label, valor e hint corretamente', () => {
    render(<Input label="Valor da recarga" hint="Mínimo R$ 5,00" />);
    const input = screen.getByLabelText('Valor da recarga');
    expect(input).toHaveAccessibleDescription('Mínimo R$ 5,00');
  });

  it('marca aria-invalid quando inválido', () => {
    render(<Input label="Valor da recarga" invalid hint="Valor abaixo do mínimo" />);
    expect(screen.getByLabelText('Valor da recarga')).toHaveAttribute('aria-invalid', 'true');
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<Input label="Valor da recarga" hint="Mínimo R$ 5,00" />);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
