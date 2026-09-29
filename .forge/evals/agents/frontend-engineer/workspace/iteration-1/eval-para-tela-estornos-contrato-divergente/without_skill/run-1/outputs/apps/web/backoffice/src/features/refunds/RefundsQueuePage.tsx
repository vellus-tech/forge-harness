import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { approveRefund, fetchPendingRefunds } from './api';
import type { Refund } from './types';

const REFUNDS_QUERY_KEY = ['refunds', 'PENDENTE'] as const;

// DD-004: estorno só é efetivado com duas aprovações de operadores distintos; a UI não pode
// remover o item da fila de forma otimista — só sai quando a API confirmar status APROVADO.
export function RefundsQueuePage() {
  const queryClient = useQueryClient();
  const [approverId, setApproverId] = useState('');

  const refundsQuery = useQuery({
    queryKey: REFUNDS_QUERY_KEY,
    queryFn: fetchPendingRefunds,
  });

  const approveMutation = useMutation({
    mutationFn: ({ id }: { id: string }) => approveRefund(id, approverId),
    onSuccess: (result, { id }) => {
      if (result.status === 'APROVADO') {
        queryClient.setQueryData<Refund[]>(REFUNDS_QUERY_KEY, (current) =>
          current?.filter((refund) => refund.id !== id),
        );
      } else {
        // AGUARDANDO_SEGUNDA_APROVACAO: item permanece na fila, apenas refletimos a 1ª aprovação.
        queryClient.invalidateQueries({ queryKey: REFUNDS_QUERY_KEY });
      }
    },
  });

  if (refundsQuery.isLoading) {
    return <p>Carregando fila de estornos…</p>;
  }

  if (refundsQuery.isError) {
    return <p role="alert">Não foi possível carregar a fila de estornos.</p>;
  }

  const refunds = refundsQuery.data ?? [];

  return (
    <main>
      <h1>Fila de estornos pendentes</h1>

      <label htmlFor="approver-id">Seu ID de operador</label>
      <input
        id="approver-id"
        value={approverId}
        onChange={(event) => setApproverId(event.target.value)}
        placeholder="ex.: operador-42"
      />

      {refunds.length === 0 ? (
        <p>Nenhum estorno pendente.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Valor</th>
              <th>Motivo</th>
              <th>Solicitado em</th>
              <th>Ação</th>
            </tr>
          </thead>
          <tbody>
            {refunds.map((refund) => (
              <tr key={refund.id}>
                <td>R$ {refund.amount}</td>
                <td>{refund.reason}</td>
                <td>{new Date(refund.requestedAt).toLocaleString('pt-BR')}</td>
                <td>
                  <button
                    type="button"
                    disabled={!approverId || approveMutation.isPending}
                    onClick={() => approveMutation.mutate({ id: refund.id })}
                  >
                    Aprovar
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {approveMutation.isError && (
        <p role="alert">Falha ao registrar aprovação. Tente novamente.</p>
      )}
    </main>
  );
}
