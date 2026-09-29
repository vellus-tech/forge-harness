import { Badge, Card } from '../../components/ds';
import type { Partner } from '../../api/partners';
import './PartnersPage.css';

export function PartnersPage({ partners, onFilter }: { partners: Partner[]; onFilter: (bu: string) => void }) {
  return (
    <Card>
      <select className="bu-filter" onChange={(e) => onFilter(e.target.value)}>
        {partners.map((p) => <option key={p.bu_id} value={p.bu_id}>{p.bu_id}</option>)}
      </select>
      <table className="partners-table">
        <tbody>
          {partners.map((p) => (
            <tr key={p.id}>
              <td>{p.name}</td>
              <td className="bu-cell">{p.bu_id}</td>
              <td><Badge>{p.role}</Badge></td>
              <td>
                <div className="onboarding-bar" style={{ ['--progress' as any]: `${p.onboarding_pct}%` }} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}
