import type { Meta, StoryObj } from '@storybook/react';
import { Wallet, CreditCard, CircleHelp } from 'lucide-react';
import { ShortcutGrid } from './ShortcutGrid.js';

const meta: Meta<typeof ShortcutGrid> = {
  title: 'Blocos/ShortcutGrid',
  component: ShortcutGrid,
  tags: ['autodocs'],
  args: {
    items: [
      { icon: Wallet, label: 'Recarregar' },
      { icon: CreditCard, label: 'Cartões' },
      { icon: CircleHelp, label: 'Ajuda' },
    ],
  },
};
export default meta;

type Story = StoryObj<typeof ShortcutGrid>;
export const Default: Story = {};
