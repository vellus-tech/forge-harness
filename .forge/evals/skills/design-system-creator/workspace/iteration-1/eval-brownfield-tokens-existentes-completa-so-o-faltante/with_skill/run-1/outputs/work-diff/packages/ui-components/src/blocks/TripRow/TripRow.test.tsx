import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { runA11y } from '../../test/axe.js';
import { TripRow } from './TripRow.js';

describe('TripRow', () => {
  it('mostra linha, horário e valor', () => {
    render(
      <ul>
        <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" />
      </ul>,
    );
    expect(screen.getByText('Linha 175')).toBeInTheDocument();
    expect(screen.getByText('Hoje, 08:12')).toBeInTheDocument();
    expect(screen.getByText('R$ 4,40')).toBeInTheDocument();
  });

  it('não tem violações de acessibilidade (success e warning)', async () => {
    const { container } = render(
      <ul>
        <TripRow line="175" when="Hoje, 08:12" amount="R$ 4,40" status="success" />
        <TripRow line="302" when="Ontem, 18:40" amount="R$ 4,40" status="warning" />
      </ul>,
    );
    await runA11y(container);
  });
});
