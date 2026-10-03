import type { Meta, StoryObj } from '@storybook/react';
import { spacing } from '@rotaviva/design-tokens';

const meta: Meta = {
  title: 'Fundamentos/Espaçamento',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

export const Escala4pt: Story = {
  render: () => (
    <div style={{ fontFamily: 'var(--font-ui)' }}>
      {Object.entries(spacing).map(([k, v]) => (
        <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 6 }}>
          <div style={{ width: v, height: 16, background: 'var(--brand)' }} />
          <code>--s-{k}</code>
        </div>
      ))}
    </div>
  ),
};
