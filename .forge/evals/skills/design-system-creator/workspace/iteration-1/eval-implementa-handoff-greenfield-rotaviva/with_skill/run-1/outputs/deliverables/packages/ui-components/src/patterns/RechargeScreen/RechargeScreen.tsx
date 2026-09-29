import { useState } from 'react';
import { Input } from '../../components/Input/Input.js';
import { Button } from '../../components/Button/Button.js';
import styles from './RechargeScreen.module.css';

export interface RechargeScreenProps {
  onConfirm?: (value: string) => void;
}

/** Composição da tela de recarga — só Storybook, não exportada na API pública. */
export function RechargeScreen({ onConfirm }: RechargeScreenProps) {
  const [value, setValue] = useState('');

  return (
    <main className={styles.main}>
      <h1 className={styles.title}>Recarregar passe</h1>
      <Input
        label="Valor da recarga"
        placeholder="R$ 0,00"
        hint="Mínimo R$ 5,00"
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      <Button variant="primary" onClick={() => onConfirm?.(value)}>
        Confirmar recarga
      </Button>
    </main>
  );
}
