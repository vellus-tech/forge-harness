import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../test/axe.js';
import { Card } from './Card.js';

describe('Card', () => {
  it('renderiza o conteúdo', () => {
    render(<Card>R$ 42,80</Card>);
    expect(screen.getByText('R$ 42,80')).toBeInTheDocument();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(<Card>R$ 42,80</Card>);
    await runA11y(container);
  });
});
