import type { Meta, StoryObj } from '@storybook/react';
import { Badge } from './Badge.js';

const meta: Meta<typeof Badge> = {
  title: 'Componentes/Badge',
  component: Badge,
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj<typeof Badge>;

export const Success: Story = { args: { status: 'success', children: 'Aprovada' } };
export const Warning: Story = { args: { status: 'warning', children: 'Pendente' } };
export const Neutral: Story = { args: { status: 'neutral', children: 'Expirada' } };
