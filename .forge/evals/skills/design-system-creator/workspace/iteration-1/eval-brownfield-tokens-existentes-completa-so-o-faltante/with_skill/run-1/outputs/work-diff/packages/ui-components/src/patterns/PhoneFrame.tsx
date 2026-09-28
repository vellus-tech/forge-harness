import type { ReactNode } from 'react';

/** Moldura leve para as telas em Storybook — só documentação, não exportada da API pública. */
export function PhoneFrame({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        width: 360,
        minHeight: 720,
        margin: '0 auto',
        border: '10px solid var(--n-900)',
        borderRadius: 36,
        overflow: 'hidden',
        background: 'var(--surface)',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {children}
    </div>
  );
}
