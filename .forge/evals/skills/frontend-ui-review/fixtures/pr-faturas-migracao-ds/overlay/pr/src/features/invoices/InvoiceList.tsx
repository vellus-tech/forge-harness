import { Button } from '../../components/ds';
import './InvoiceList.css';

type Invoice = { id: string; number: string; amount: number; status: 'paid' | 'open' };

export function InvoiceList({ invoices, onUpload }: { invoices: Invoice[]; onUpload: (f: File | null) => void }) {
  return (
    <section className="invoice-list">
      <header className="invoice-list__header">
        <h2>Faturas</h2>
        <input type="file" className="invoice-upload" onChange={(e) => onUpload(e.target.files?.[0] ?? null)} />
        <Button>Nova fatura</Button>
      </header>
      {invoices.map((inv) => (
        <article key={inv.id} className="invoice-card">
          <span>{inv.number}</span>
          <strong>{inv.amount.toFixed(2)}</strong>
        </article>
      ))}
    </section>
  );
}
