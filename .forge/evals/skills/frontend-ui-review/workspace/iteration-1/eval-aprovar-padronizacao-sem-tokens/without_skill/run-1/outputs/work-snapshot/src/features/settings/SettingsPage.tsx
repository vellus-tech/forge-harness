import { Button, Input } from '@acme/ui';
import './SettingsPage.css';
export function SettingsPage() {
  return (
    <section className="settings-card">
      <h2 className="settings-title">Configurações</h2>
      <Input label="Nome da empresa" />
      <Button>Salvar</Button>
    </section>
  );
}
