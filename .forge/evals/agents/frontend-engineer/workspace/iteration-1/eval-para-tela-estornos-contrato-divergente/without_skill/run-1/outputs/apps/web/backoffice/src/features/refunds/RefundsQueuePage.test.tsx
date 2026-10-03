import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RefundsQueuePage } from './RefundsQueuePage';
import * as api from './api';

function renderWithClient() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <RefundsQueuePage />
    </QueryClientProvider>,
  );
}

describe('RefundsQueuePage', () => {
  beforeEach(() => {
    vi.spyOn(api, 'fetchPendingRefunds').mockResolvedValue([
      { id: 'rf-1', amount: '12.50', reason: 'Cobrança duplicada', requestedAt: '2026-09-20T10:00:00Z' },
    ]);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('mantém o item na fila quando a API responde AGUARDANDO_SEGUNDA_APROVACAO (sem update otimista)', async () => {
    const approveSpy = vi
      .spyOn(api, 'approveRefund')
      .mockResolvedValue({ approvals: 1, status: 'AGUARDANDO_SEGUNDA_APROVACAO' });

    renderWithClient();

    await screen.findByText('R$ 12.50');
    await userEvent.type(screen.getByLabelText('Seu ID de operador'), 'operador-1');
    await userEvent.click(screen.getByRole('button', { name: 'Aprovar' }));

    await waitFor(() => expect(approveSpy).toHaveBeenCalledWith('rf-1', 'operador-1'));
    expect(screen.getByText('R$ 12.50')).toBeInTheDocument();
  });

  it('remove o item da fila somente quando a API confirma status APROVADO', async () => {
    vi.spyOn(api, 'approveRefund').mockResolvedValue({ approvals: 2, status: 'APROVADO' });

    renderWithClient();

    await screen.findByText('R$ 12.50');
    await userEvent.type(screen.getByLabelText('Seu ID de operador'), 'operador-2');
    await userEvent.click(screen.getByRole('button', { name: 'Aprovar' }));

    await waitFor(() => expect(screen.queryByText('R$ 12.50')).not.toBeInTheDocument());
  });
});
