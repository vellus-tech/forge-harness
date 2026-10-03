import { describe, it, expect } from 'vitest';
import type { ComponentProps } from 'react';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../../test/axe.js';
import { TripRow } from './TripRow.js';

function renderRow(props: ComponentProps<typeof TripRow>) {
  return render(
    <ul>
      <TripRow {...props} />
    </ul>,
  );
}

describe('TripRow', () => {
  it('exibe linha, horário e valor', () => {
    renderRow({ line: '175', when: 'Hoje, 08:12', amount: 'R$ 4,40', status: 'success' });
    expect(screen.getByText('Linha 175')).toBeInTheDocument();
    expect(screen.getByText('Hoje, 08:12')).toBeInTheDocument();
    expect(screen.getByText('R$ 4,40')).toBeInTheDocument();
  });

  it.each(['success', 'warning', 'neutral'] as const)('não tem violações de a11y no status %s', async (status) => {
    const { container } = renderRow({ line: '175', when: 'Hoje, 08:12', amount: 'R$ 4,40', status });
    expect(await runA11y(container)).toHaveNoViolations();
  });
});
