import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button.js';

const meta: Meta<typeof Button> = {
  title: 'Componentes/Button',
  component: Button,
  tags: ['autodocs'],
  args: { children: 'Recarregar' },
};
export default meta;

type Story = StoryObj<typeof Button>;

export const Primary: Story = { args: { variant: 'primary' } };
export const Secondary: Story = { args: { variant: 'secondary', children: 'Ver extrato' } };
export const Ghost: Story = { args: { variant: 'ghost', children: 'Cancelar' } };
export const Danger: Story = { args: { variant: 'danger', children: 'Bloquear cartão' } };
export const Small: Story = { args: { variant: 'primary', size: 'sm', children: 'Ok' } };
export const Disabled: Story = { args: { variant: 'primary', disabled: true } };
