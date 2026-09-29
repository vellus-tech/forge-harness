import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { vi } from 'vitest';
import { RechargeForm } from './RechargeForm';
import * as rechargeService from '../../services/rechargeService';
import { RechargeBusinessError } from '../../services/rechargeService';

function renderWithClient(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

describe('RechargeForm', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('recarrega com um valor rápido e mostra a confirmação com o status retornado', async () => {
    const user = userEvent.setup();
    vi.spyOn(rechargeService, 'requestRecharge').mockResolvedValue({ rechargeId: 'r-1', status: 'CONFIRMED' });

    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.click(screen.getByRole('button', { name: /R\$\s*20,00/ }));
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    expect(await screen.findByRole('status')).toHaveTextContent('confirmada');
    expect(rechargeService.requestRecharge).toHaveBeenCalledWith(
      expect.objectContaining({ cardId: 'c-1', amountCents: 2000 }),
    );
  });

  it('exibe erro no campo e não chama a API quando o valor digitado está fora da faixa', async () => {
    const user = userEvent.setup();
    const spy = vi.spyOn(rechargeService, 'requestRecharge');

    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.type(screen.getByLabelText('Outro valor'), '1,00');
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('R$ 5,00 e R$ 500,00');
    expect(spy).not.toHaveBeenCalled();
  });

  it('mostra a mensagem de negócio da API e preserva o valor digitado', async () => {
    const user = userEvent.setup();
    vi.spyOn(rechargeService, 'requestRecharge').mockRejectedValue(
      new RechargeBusinessError('CARTAO_BLOQUEADO', 'Cartão bloqueado. Procure um ponto de atendimento.'),
    );

    renderWithClient(<RechargeForm cardId="c-1" />);

    const input = screen.getByLabelText('Outro valor');
    await user.type(input, '15,00');
    await user.click(screen.getByRole('button', { name: 'Recarregar' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Cartão bloqueado');
    expect(input).toHaveValue('15,00');
  });

  it('não duplica a cobrança quando o botão de enviar é clicado mais de uma vez', async () => {
    const user = userEvent.setup();
    let resolveRequest: (value: { rechargeId: string; status: 'CONFIRMED' }) => void = () => {};
    vi.spyOn(rechargeService, 'requestRecharge').mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveRequest = resolve;
        }),
    );

    renderWithClient(<RechargeForm cardId="c-1" />);

    await user.click(screen.getByRole('button', { name: /R\$\s*10,00/ }));
    const submitButton = screen.getByRole('button', { name: 'Recarregar' });
    await user.click(submitButton);
    await user.click(submitButton);
    await user.click(submitButton);

    expect(rechargeService.requestRecharge).toHaveBeenCalledTimes(1);
    resolveRequest({ rechargeId: 'r-2', status: 'CONFIRMED' });
  });
});
