import { useState } from 'react';
import { buildPeriodQuery, filterByPeriod, formatCurrency, logFilterUsage } from './utils';

export function StatementPage({ entries, userCpf }: { entries: StatementEntry[]; userCpf: string }) {
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const rows = filterByPeriod(entries, start, end);
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion -- ver ISSUE-412
  const periodInput = document.getElementById('period')!;
  logFilterUsage(userCpf, buildPeriodQuery(start, end));
  return (
    <section aria-labelledby={periodInput.id}>
      <input type="date" value={start} onChange={(e) => setStart(e.target.value)} />
      <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} />
      <table>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              <td>{row.date}</td>
              <td>{formatCurrency(row.amountCents)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export interface StatementEntry {
  id: string;
  date: string;
  amountCents: number;
}
