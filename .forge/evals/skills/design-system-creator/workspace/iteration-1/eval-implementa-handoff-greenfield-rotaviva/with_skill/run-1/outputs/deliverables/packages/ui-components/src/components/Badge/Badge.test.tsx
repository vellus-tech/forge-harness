import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../../test/axe.js';
import { Badge } from './Badge.js';

describe('Badge', () => {
  it.each(['success', 'warning', 'neutral'] as const)('renderiza status %s', (status) => {
    render(<Badge status={status}>Texto</Badge>);
    expect(screen.getByText('Texto')).toBeInTheDocument();
  });

  it('não tem violações de a11y', async () => {
    const { container } = render(<Badge status="success">Aprovada</Badge>);
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
