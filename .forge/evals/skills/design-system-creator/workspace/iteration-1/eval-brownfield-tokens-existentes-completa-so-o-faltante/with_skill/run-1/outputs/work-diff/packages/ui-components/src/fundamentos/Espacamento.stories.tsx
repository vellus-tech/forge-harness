import type { Meta, StoryObj } from '@storybook/react';
import { spacing } from '@rotaviva/design-tokens';

function Spacing() {
  return (
    <div>
      {Object.entries(spacing).map(([k, v]) => (
        <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
          <div style={{ width: v, height: 16, background: 'var(--brand)' }} />
          <code>
            --s-{k}: {v}
          </code>
        </div>
      ))}
    </div>
  );
}

const meta: Meta<typeof Spacing> = {
  title: 'Fundamentos/Espaçamento',
  component: Spacing,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof Spacing> = {};
