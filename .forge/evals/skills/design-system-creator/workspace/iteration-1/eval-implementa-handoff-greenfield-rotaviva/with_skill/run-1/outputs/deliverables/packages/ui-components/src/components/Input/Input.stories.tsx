import type { Meta, StoryObj } from '@storybook/react';
import { Input } from './Input.js';

const meta: Meta<typeof Input> = {
  title: 'Componentes/Input',
  component: Input,
  tags: ['autodocs'],
  args: { label: 'Valor da recarga', placeholder: 'R$ 0,00' },
};
export default meta;

type Story = StoryObj<typeof Input>;

export const Default: Story = { args: { hint: 'Mínimo R$ 5,00' } };
export const Invalid: Story = { args: { hint: 'Valor abaixo do mínimo', invalid: true } };
