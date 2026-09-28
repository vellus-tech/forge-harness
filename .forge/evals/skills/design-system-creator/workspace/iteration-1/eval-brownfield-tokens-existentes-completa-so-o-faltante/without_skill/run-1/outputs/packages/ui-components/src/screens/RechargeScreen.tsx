import { useState } from 'react';
import { Input } from '../primitives/Input.js';
import { Button } from '../primitives/Button.js';

export type RechargeScreenProps = {
  onConfirm?: (value: string) => void;
};

/** Tela de recarga: valor + confirmação (fluxo Início → Recarregar → Confirmação). */
export function RechargeScreen({ onConfirm }: RechargeScreenProps) {
  const [value, setValue] = useState('');

  return (
    <main className="screen">
      <h1>Recarregar passe</h1>
      <Input
        label="Valor da recarga"
        placeholder="R$ 0,00"
        inputMode="decimal"
        hint="Mínimo R$ 5,00"
        value={value}
        onChange={(e) => setValue(e.target.value)}
      />
      <Button variant="primary" onClick={() => onConfirm?.(value)}>
        Confirmar recarga
      </Button>
    </main>
  );
}
