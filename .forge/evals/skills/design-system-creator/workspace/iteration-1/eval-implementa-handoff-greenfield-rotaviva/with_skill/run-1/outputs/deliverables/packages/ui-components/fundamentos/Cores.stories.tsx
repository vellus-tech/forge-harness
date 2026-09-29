import type { Meta, StoryObj } from '@storybook/react';
import { brand, neutral, semantic, surface, foreground } from '@rotaviva/design-tokens';

const meta: Meta = {
  title: 'Fundamentos/Cores',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

function Swatch({ name, value }: { name: string; value: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
      <div style={{ width: 40, height: 40, borderRadius: 8, background: value, border: '1px solid var(--n-100)' }} />
      <code>{name}</code>
    </div>
  );
}

export const Paleta: Story = {
  render: () => (
    <div style={{ fontFamily: 'var(--font-ui)' }}>
      <h2>Marca</h2>
      {Object.entries(brand).map(([k, v]) => (
        <Swatch key={k} name={`brand.${k}`} value={v} />
      ))}
      <h2>Neutros</h2>
      {Object.entries(neutral).map(([k, v]) => (
        <Swatch key={k} name={`neutral.${k}`} value={v} />
      ))}
      <h2>Semânticas</h2>
      {Object.entries(semantic).map(([k, v]) => (
        <Swatch key={k} name={`semantic.${k}`} value={v} />
      ))}
      <h2>Superfície e texto</h2>
      {Object.entries(surface).map(([k, v]) => (
        <Swatch key={k} name={`surface.${k}`} value={v} />
      ))}
      {Object.entries(foreground).map(([k, v]) => (
        <Swatch key={k} name={`foreground.${k}`} value={v} />
      ))}
      <p style={{ maxWidth: 560, color: 'var(--fg-muted)' }}>
        <strong>Caveat de contraste:</strong> brand (#0F9D8A) sobre branco ≈ 3.4:1 — suficiente
        para texto grande, ícones e CTAs curtos; no limite para texto normal. Decisão do handoff
        (ver chat de design): reservar a cor de marca para CTAs curtos e ícones-ação.
      </p>
    </div>
  ),
};
