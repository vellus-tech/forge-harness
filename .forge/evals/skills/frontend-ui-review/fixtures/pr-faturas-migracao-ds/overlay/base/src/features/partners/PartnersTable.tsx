import './PartnersTable.css';
export function PartnersTable({ rows }: { rows: { id: string; name: string; unread: boolean }[] }) {
  return (
    <table className="partners">
      <tbody>
        {rows.map((r) => (
          <tr key={r.id} className={r.unread ? 'row-unread' : undefined}><td>{r.name}</td></tr>
        ))}
      </tbody>
    </table>
  );
}
