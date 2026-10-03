import type { Meta, StoryObj } from '@storybook/react';
import { typography } from '@rotaviva/design-tokens';

const meta: Meta = {
  title: 'Fundamentos/Tipografia',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

export const Escala: Story = {
  render: () => (
    <div>
      <p style={{ fontFamily: typography.fontDisplay, fontWeight: 700, fontSize: typography.size[28] }}>
        Display Sora — 28
      </p>
      <p style={{ fontFamily: typography.fontUi, fontSize: typography.size[20] }}>UI Manrope — 20</p>
      <p style={{ fontFamily: typography.fontUi, fontSize: typography.size[16] }}>UI Manrope — 16</p>
      <p style={{ fontFamily: typography.fontUi, fontSize: typography.size[14] }}>UI Manrope — 14</p>
      <p style={{ fontFamily: typography.fontUi, fontSize: typography.size[12] }}>UI Manrope — 12</p>
    </div>
  ),
};
