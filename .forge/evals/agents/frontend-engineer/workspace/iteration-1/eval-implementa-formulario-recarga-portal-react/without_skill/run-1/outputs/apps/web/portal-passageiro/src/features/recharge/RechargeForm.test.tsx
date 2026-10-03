import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { RechargeForm } from './RechargeForm';
import * as rechargeService from '../../services/rechargeService';
import { HttpError } from '../../services/httpClient';

function renderWithClient(ui: React.ReactElement) {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

describe('RechargeForm', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('recarrega com um valor rápido e mostra a confirmação (REQ-RC-01, REQ-RC-05)', async () => {
    const user = userEvent.setup();
    vi.spyOn(rechargeService, 'postRecharge').mockResolvedValue({ rechargeId: 'r-1', status: 'CONFIRMED' });
    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.click(screen.getByRole('button', { name: /R\$\s*20,00/ }));
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    await waitFor(() =>
      expect(rechargeService.postRecharge).toHaveBeenCalledWith('c-1', 2000, expect.any(String)),
    );
    expect(await screen.findByText(/Confirmada/)).toBeInTheDocument();
  });

  it('rejeita outro valor fora da faixa sem chamar a API (REQ-RC-02)', async () => {
    const user = userEvent.setup();
    const postRechargeSpy = vi.spyOn(rechargeService, 'postRecharge');
    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.type(screen.getByLabelText('Outro valor'), '1');
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('entre R$ 5,00 e R$ 500,00');
    expect(postRechargeSpy).not.toHaveBeenCalled();
  });

  it('mostra o erro de negócio da API e preserva o valor digitado (REQ-RC-03)', async () => {
    const user = userEvent.setup();
    vi.spyOn(rechargeService, 'postRecharge').mockRejectedValue(
      new HttpError(422, { code: 'LIMITE_DIARIO_EXCEDIDO', message: 'Limite diário excedido.' }),
    );
    renderWithClient(<RechargeForm cardId="c-1" />);

    const input = screen.getByLabelText('Outro valor');
    await user.type(input, '50');
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Limite diário excedido.');
    expect(input).toHaveValue('50');
  });

  it('desabilita o envio durante a requisição para não duplicar a cobrança (REQ-RC-04)', async () => {
    const user = userEvent.setup();
    let resolvePromise: (value: rechargeService.RechargeResponse) => void = () => {};
    vi.spyOn(rechargeService, 'postRecharge').mockImplementation(
      () =>
        new Promise((resolve) => {
          resolvePromise = resolve;
        }),
    );
    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.click(screen.getByRole('button', { name: /R\$\s*10,00/ }));
    const submitButton = screen.getByRole('button', { name: 'Recarregar' });
    await user.click(submitButton);

    expect(submitButton).toBeDisabled();
    await user.click(submitButton);

    resolvePromise({ rechargeId: 'r-2', status: 'PENDING_PAYMENT' });
    await waitFor(() => expect(rechargeService.postRecharge).toHaveBeenCalledTimes(1));
  });
});
