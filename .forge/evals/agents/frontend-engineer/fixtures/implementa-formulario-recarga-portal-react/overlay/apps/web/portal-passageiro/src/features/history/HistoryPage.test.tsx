import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { vi } from 'vitest';
import { HistoryPage } from './HistoryPage';
import * as historyService from '../../services/historyService';

function renderWithClient(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

describe('HistoryPage', () => {
  it('mostra mensagem de vazio quando o cartão não tem movimentação', async () => {
    vi.spyOn(historyService, 'fetchHistory').mockResolvedValue([]);
    renderWithClient(<HistoryPage cardId="c-1" />);
    expect(await screen.findByText('Nenhuma movimentação neste cartão.')).toBeInTheDocument();
  });

  it('mostra alerta quando a API falha', async () => {
    vi.spyOn(historyService, 'fetchHistory').mockRejectedValue(new Error('boom'));
    renderWithClient(<HistoryPage cardId="c-1" />);
    expect(await screen.findByRole('alert')).toHaveTextContent('Não foi possível carregar o histórico');
  });
});
