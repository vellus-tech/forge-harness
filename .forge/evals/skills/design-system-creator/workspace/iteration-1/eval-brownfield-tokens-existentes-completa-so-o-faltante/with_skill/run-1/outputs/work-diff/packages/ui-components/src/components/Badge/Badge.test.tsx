import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../test/axe.js';
import { Badge } from './Badge.js';

describe('Badge', () => {
  it.each(['success', 'warning', 'neutral'] as const)('renderiza o status %s', (status) => {
    render(<Badge status={status}>Aprovada</Badge>);
    expect(screen.getByText('Aprovada')).toBeInTheDocument();
  });

  it('não tem violações de acessibilidade', async () => {
    const { container } = render(
      <>
        <Badge status="success">Aprovada</Badge>
        <Badge status="warning">Pendente</Badge>
        <Badge status="neutral">Expirada</Badge>
      </>,
    );
    await runA11y(container);
  });
});
