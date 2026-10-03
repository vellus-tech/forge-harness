import type { Meta, StoryObj } from '@storybook/react';
import { PhoneFrame } from './PhoneFrame.js';
import { RechargeScreen } from './RechargeScreen.js';

const meta: Meta<typeof RechargeScreen> = {
  title: 'Padrões/RechargeScreen',
  component: RechargeScreen,
  tags: ['autodocs'],
  decorators: [(Story) => <PhoneFrame><Story /></PhoneFrame>],
};
export default meta;

type Story = StoryObj<typeof RechargeScreen>;

export const Default: Story = {};
