import type { Meta, StoryObj } from '@storybook/react';
import { Bell, Wallet, CreditCard, CircleHelp, Bus } from 'lucide-react';
import { Icon } from '@rotaviva/icons';

const meta: Meta = {
  title: 'Fundamentos/Iconografia',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

const ICONS = [
  { icon: Bell, label: 'Bell' },
  { icon: Wallet, label: 'Wallet' },
  { icon: CreditCard, label: 'CreditCard' },
  { icon: CircleHelp, label: 'CircleHelp' },
  { icon: Bus, label: 'Bus' },
];

export const Catalogo: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: 24, fontFamily: 'var(--font-ui)' }}>
      {ICONS.map(({ icon, label }) => (
        <div key={label} style={{ textAlign: 'center' }}>
          <Icon icon={icon} size={24} />
          <div>
            <code>{label}</code>
          </div>
        </div>
      ))}
    </div>
  ),
};
