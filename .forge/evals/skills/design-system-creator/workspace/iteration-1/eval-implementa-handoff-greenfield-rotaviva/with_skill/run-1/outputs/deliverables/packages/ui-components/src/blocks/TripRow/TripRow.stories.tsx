import type { Meta, StoryObj } from '@storybook/react';
import { TripRow } from './TripRow.js';

const meta: Meta<typeof TripRow> = {
  title: 'Blocos/TripRow',
  component: TripRow,
  tags: ['autodocs'],
  render: (args) => (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, width: 360 }}>
      <TripRow {...args} />
    </ul>
  ),
};
export default meta;

type Story = StoryObj<typeof TripRow>;

export const Aprovada: Story = { args: { line: '175', when: 'Hoje, 08:12', amount: 'R$ 4,40', status: 'success' } };
export const Pendente: Story = { args: { line: '302', when: 'Ontem, 18:40', amount: 'R$ 4,40', status: 'warning' } };
export const Expirada: Story = { args: { line: '410', when: '12/09, 09:03', amount: 'R$ 4,40', status: 'neutral' } };
