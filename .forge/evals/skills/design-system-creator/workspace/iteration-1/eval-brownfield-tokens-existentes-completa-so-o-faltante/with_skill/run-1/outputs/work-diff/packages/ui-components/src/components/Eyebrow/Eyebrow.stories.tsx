import type { Meta, StoryObj } from '@storybook/react';
import { Eyebrow } from './Eyebrow.js';

const meta: Meta<typeof Eyebrow> = {
  title: 'Componentes/Eyebrow',
  component: Eyebrow,
  tags: ['autodocs'],
  args: { children: 'Saldo do passe' },
};
export default meta;

type Story = StoryObj<typeof Eyebrow>;

export const Default: Story = {};
