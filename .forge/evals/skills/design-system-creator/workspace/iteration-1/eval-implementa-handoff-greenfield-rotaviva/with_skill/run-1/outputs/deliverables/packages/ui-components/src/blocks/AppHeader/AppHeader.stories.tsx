import type { Meta, StoryObj } from '@storybook/react';
import { AppHeader } from './AppHeader.js';

const meta: Meta<typeof AppHeader> = {
  title: 'Blocos/AppHeader',
  component: AppHeader,
  tags: ['autodocs'],
  args: { name: 'Ana' },
};
export default meta;

type Story = StoryObj<typeof AppHeader>;
export const Default: Story = {};
