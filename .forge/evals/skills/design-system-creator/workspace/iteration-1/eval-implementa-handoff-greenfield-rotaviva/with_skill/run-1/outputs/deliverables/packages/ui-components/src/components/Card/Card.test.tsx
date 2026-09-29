import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../../test/axe.js';
import { Card } from './Card.js';

describe('Card', () => {
  it('renderiza o conteúdo filho', () => {
    render(<Card>Conteúdo</Card>);
    expect(screen.getByText('Conteúdo')).toBeInTheDocument();
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<Card>Conteúdo</Card>);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
