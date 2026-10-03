import { useState } from 'react';
import { Input } from '../components/Input/Input.js';
import { Button } from '../components/Button/Button.js';

export interface RechargeScreenProps {
  onConfirm?: (value: string) => void;
}

/** Composição da tela Recarregar — não exportada da API pública, só para Storybook/Padrões. */
export function RechargeScreen({ onConfirm }: RechargeScreenProps) {
  const [value, setValue] = useState('');
  return (
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 16, flex: 1 }}>
      <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--fs-20)', margin: 0 }}>
        Recarregar passe
      </h1>
      <Input
        label="Valor da recarga"
        hint="Mínimo R$ 5,00"
        placeholder="R$ 0,00"
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      <Button variant="primary" onClick={() => onConfirm?.(value)}>
        Confirmar recarga
      </Button>
    </div>
  );
}
