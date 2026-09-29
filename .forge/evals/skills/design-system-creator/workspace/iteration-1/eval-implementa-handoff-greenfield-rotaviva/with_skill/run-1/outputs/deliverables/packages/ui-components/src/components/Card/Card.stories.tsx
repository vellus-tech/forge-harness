import type { Meta, StoryObj } from '@storybook/react';
import { Card } from './Card.js';
import { Eyebrow } from '../Eyebrow/Eyebrow.js';

const meta: Meta<typeof Card> = {
  title: 'Componentes/Card',
  component: Card,
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj<typeof Card>;

export const Default: Story = {
  render: () => (
    <Card>
      <Eyebrow>Saldo do passe</Eyebrow>
      <p>R$ 42,80</p>
    </Card>
  ),
};
