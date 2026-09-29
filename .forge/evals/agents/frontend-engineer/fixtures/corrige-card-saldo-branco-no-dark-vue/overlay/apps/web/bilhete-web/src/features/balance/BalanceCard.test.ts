import { render, screen } from '@testing-library/vue';
import '@testing-library/jest-dom/vitest';
import BalanceCard from './BalanceCard.vue';

describe('BalanceCard', () => {
  it('mostra o saldo formatado em reais', () => {
    render(BalanceCard, { props: { balanceCents: 1250, cardAlias: 'Cartão Trabalho' } });
    expect(screen.getByText('R$ 12,50', { normalize: (s) => s.replace(/\s/g, ' ') })).toBeInTheDocument();
  });
});
