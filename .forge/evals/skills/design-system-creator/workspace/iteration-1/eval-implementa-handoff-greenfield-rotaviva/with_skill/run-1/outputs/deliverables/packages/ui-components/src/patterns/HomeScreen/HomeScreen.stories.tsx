import type { Meta, StoryObj } from '@storybook/react';
import { PhoneFrame } from '../PhoneFrame/PhoneFrame.js';
import { HomeScreen } from './HomeScreen.js';

const meta: Meta<typeof HomeScreen> = {
  title: 'Padrões/HomeScreen',
  component: HomeScreen,
  tags: ['autodocs'],
  decorators: [(Story) => <PhoneFrame><Story /></PhoneFrame>],
};
export default meta;

type Story = StoryObj<typeof HomeScreen>;
export const Default: Story = {};
