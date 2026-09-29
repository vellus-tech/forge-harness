import type { Meta, StoryObj } from '@storybook/react';
import { radius, shadow } from '@rotaviva/design-tokens';

const meta: Meta = {
  title: 'Fundamentos/Raios e Sombras',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

export const Amostras: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 24, fontFamily: 'var(--font-ui)' }}>
      {Object.entries(radius).map(([k, v]) => (
        <div key={k} style={{ textAlign: 'center' }}>
          <div style={{ width: 64, height: 64, background: 'var(--surface-muted)', borderRadius: v }} />
          <code>--r-{k}</code>
        </div>
      ))}
      {Object.entries(shadow).map(([k, v]) => (
        <div key={k} style={{ textAlign: 'center' }}>
          <div style={{ width: 64, height: 64, background: 'var(--surface)', boxShadow: v, borderRadius: 12 }} />
          <code>--shadow-{k}</code>
        </div>
      ))}
    </div>
  ),
};
