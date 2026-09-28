import type { Meta, StoryObj } from '@storybook/react';
import { brand } from '@rotaviva/design-tokens';

/*
 * `packages/design-tokens` (brownfield, já existente) só exporta objetos TS
 * tipados para `brand`, `spacing`, `radius` e `typography` (ver `src/tokens/*`).
 * Neutros e semânticas vivem só como CSS custom properties em `tokens.css` —
 * por isso as swatches abaixo usam `var(--n-*)`/`var(--*)` em vez de um
 * objeto JS que não existe no pacote (nada de reintroduzir hex aqui).
 */
const cssVarGroups = {
  Neutros: ['--n-0', '--n-50', '--n-100', '--n-300', '--n-500', '--n-700', '--n-900'],
  Semânticas: ['--success', '--warning', '--danger', '--info'],
  'Surface / fg': ['--surface', '--surface-muted', '--fg', '--fg-muted'],
} as const;

function Swatch({ name, value }: { name: string; value: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
      <div
        style={{
          width: 48,
          height: 48,
          borderRadius: 8,
          background: value,
          border: '1px solid #0002',
        }}
      />
      <code>{name}</code>
    </div>
  );
}

function Palette() {
  return (
    <div>
      <h3>Brand (objeto TS @rotaviva/design-tokens)</h3>
      {Object.entries(brand).map(([k, v]) => (
        <Swatch key={k} name={`brand.${k}: ${v}`} value={v} />
      ))}
      {Object.entries(cssVarGroups).map(([group, vars]) => (
        <div key={group}>
          <h3>{group}</h3>
          {vars.map((v) => (
            <Swatch key={v} name={`var(${v})`} value={`var(${v})`} />
          ))}
        </div>
      ))}
    </div>
  );
}

const meta: Meta<typeof Palette> = {
  title: 'Fundamentos/Cores',
  component: Palette,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof Palette> = {};
