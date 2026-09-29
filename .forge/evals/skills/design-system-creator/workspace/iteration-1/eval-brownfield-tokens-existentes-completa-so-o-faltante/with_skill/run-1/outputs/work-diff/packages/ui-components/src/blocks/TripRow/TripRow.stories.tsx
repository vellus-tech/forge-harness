import type { Meta, StoryObj } from '@storybook/react';
import { TripRow } from './TripRow.js';

const meta: Meta<typeof TripRow> = {
  title: 'Blocos/TripRow',
  component: TripRow,
  tags: ['autodocs'],
  decorators: [(Story) => <ul style={{ listStyle: 'none', padding: 0 }}><Story /></ul>],
};
export default meta;

type Story = StoryObj<typeof TripRow>;

export const Success: Story = {
  args: { line: '175', when: 'Hoje, 08:12', amount: 'R$ 4,40', status: 'success' },
};
export const Warning: Story = {
  args: { line: '302', when: 'Ontem, 18:40', amount: 'R$ 4,40', status: 'warning' },
};
