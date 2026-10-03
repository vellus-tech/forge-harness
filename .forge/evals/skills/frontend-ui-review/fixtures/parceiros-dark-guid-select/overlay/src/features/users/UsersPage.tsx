import './UsersPage.css';
export function UsersPage({ onRole }: { onRole: (r: string) => void }) {
  return (
    <select className="role-select" onChange={(e) => onRole(e.target.value)}>
      <option value="tenant_admin">tenant_admin</option>
      <option value="partner_viewer">partner_viewer</option>
    </select>
  );
}
