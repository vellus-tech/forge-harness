import { useQuery } from '@tanstack/react-query';
import { fetchHistory } from '../../services/historyService';
import styles from './HistoryPage.module.css';

const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

export function HistoryPage({ cardId }: { cardId: string }) {
  const { data, isPending, isError } = useQuery({
    queryKey: ['history', cardId],
    queryFn: () => fetchHistory(cardId),
  });

  if (isPending) return <p role="status">Carregando histórico…</p>;
  if (isError) return <p role="alert">Não foi possível carregar o histórico. Tente novamente.</p>;
  if (data.length === 0) return <p>Nenhuma movimentação neste cartão.</p>;

  return (
    <ul className={styles.list} aria-label="Histórico do cartão">
      {data.map((entry) => (
        <li key={entry.id} className={styles.item}>
          <span>{entry.description}</span>
          <span className={styles.amount}>{currency.format(entry.amountCents / 100)}</span>
        </li>
      ))}
    </ul>
  );
}
