import type { Meta, StoryObj } from '@storybook/react';
import { BalanceCard } from './BalanceCard.js';

const meta: Meta<typeof BalanceCard> = {
  title: 'Blocos/BalanceCard',
  component: BalanceCard,
  tags: ['autodocs'],
  args: { balance: 'R$ 42,80', passName: 'Passe Comum' },
};
export default meta;

type Story = StoryObj<typeof BalanceCard>;

export const Default: Story = {};
