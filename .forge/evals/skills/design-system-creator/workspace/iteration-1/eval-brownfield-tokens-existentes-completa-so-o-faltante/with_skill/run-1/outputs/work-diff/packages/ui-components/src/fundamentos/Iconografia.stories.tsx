import type { Meta, StoryObj } from '@storybook/react';
import { Bell, Bus, Wallet, CreditCard, CircleHelp, Home, Route, User } from 'lucide-react';
import { Icon, RotavivaMark } from '@rotaviva/icons';

function Iconography() {
  const icons = [Bell, Bus, Wallet, CreditCard, CircleHelp, Home, Route, User];
  return (
    <div>
      <h3>Mark (PNG real — nunca SVG próprio)</h3>
      <div style={{ display: 'flex', gap: 16, marginBottom: 24 }}>
        <RotavivaMark variant="teal" size={40} />
        <RotavivaMark variant="black" size={40} />
        <div style={{ background: '#14202A', padding: 8 }}>
          <RotavivaMark variant="white" size={40} />
        </div>
      </div>
      <h3>Ícones (lucide-react via @rotaviva/icons)</h3>
      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
        {icons.map((IconGlyph, i) => (
          <Icon key={i} icon={IconGlyph} size={24} />
        ))}
      </div>
    </div>
  );
}

const meta: Meta<typeof Iconography> = {
  title: 'Fundamentos/Iconografia',
  component: Iconography,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof Iconography> = {};
