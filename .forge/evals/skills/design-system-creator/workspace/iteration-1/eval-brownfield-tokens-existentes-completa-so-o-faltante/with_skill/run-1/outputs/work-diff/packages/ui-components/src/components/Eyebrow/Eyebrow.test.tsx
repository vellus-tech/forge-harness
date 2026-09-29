import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../test/axe.js';
import { Eyebrow } from './Eyebrow.js';

describe('Eyebrow', () => {
  it('renderiza o texto', () => {
    render(<Eyebrow>Saldo do passe</Eyebrow>);
    expect(screen.getByText('Saldo do passe')).toBeInTheDocument();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<Eyebrow>Saldo do passe</Eyebrow>);
    await runA11y(container);
  });
});
