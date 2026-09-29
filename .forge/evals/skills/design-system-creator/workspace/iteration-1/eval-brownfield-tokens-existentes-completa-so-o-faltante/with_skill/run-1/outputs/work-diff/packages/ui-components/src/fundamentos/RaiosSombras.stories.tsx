import type { Meta, StoryObj } from '@storybook/react';
import { radius } from '@rotaviva/design-tokens';

/*
 * `shadow` não é exportado como objeto TS pelo pacote de tokens existente
 * (só `--shadow-1`/`--shadow-2` em CSS) — usamos var() em vez de recriar o
 * objeto ou hardcodar o valor rgba.
 */
function RadiiShadows() {
  return (
    <div>
      <h3>Raios</h3>
      {Object.entries(radius).map(([k, v]) => (
        <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <div
            style={{ width: 64, height: 64, borderRadius: v, background: 'var(--surface-muted)' }}
          />
          <code>
            --r-{k}: {v}
          </code>
        </div>
      ))}
      <h3>Sombras</h3>
      {['--shadow-1', '--shadow-2'].map((v) => (
        <div key={v} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <div
            style={{
              width: 96,
              height: 48,
              borderRadius: 8,
              background: 'var(--surface)',
              boxShadow: `var(${v})`,
            }}
          />
          <code>var({v})</code>
        </div>
      ))}
    </div>
  );
}

const meta: Meta<typeof RadiiShadows> = {
  title: 'Fundamentos/Raios e Sombras',
  component: RadiiShadows,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof RadiiShadows> = {};
