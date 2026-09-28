import { useState } from 'react';

export function StatementPage({ entries }: { entries: StatementEntry[] }) {
  const [rows] = useState(entries);
  return (
    <table>
      <tbody>
        {rows.map((row) => (
          <tr key={row.id}>
            <td>{row.date}</td>
            <td>{(row.amountCents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export interface StatementEntry {
  id: string;
  date: string;
  amountCents: number;
}
