import type { Meta, StoryObj } from '@storybook/react';
import { BottomNav } from './BottomNav.js';

const meta: Meta<typeof BottomNav> = {
  title: 'Blocos/BottomNav',
  component: BottomNav,
  tags: ['autodocs'],
  args: { active: 'Início' },
};
export default meta;

type Story = StoryObj<typeof BottomNav>;
export const Default: Story = {};
