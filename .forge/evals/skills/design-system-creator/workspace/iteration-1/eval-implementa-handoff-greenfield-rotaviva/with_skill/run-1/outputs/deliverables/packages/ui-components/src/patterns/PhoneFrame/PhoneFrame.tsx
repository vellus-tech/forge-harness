import type { ReactNode } from 'react';
import styles from './PhoneFrame.module.css';

export interface PhoneFrameProps {
  children: ReactNode;
}

/**
 * Moldura leve de telefone — só para o Storybook (categoria Padrões).
 * Não faz parte da API pública do pacote.
 */
export function PhoneFrame({ children }: PhoneFrameProps) {
  return (
    <div className={styles.frame}>
      <div className={styles.content}>{children}</div>
    </div>
  );
}
