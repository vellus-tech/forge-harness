import type { Meta, StoryObj } from '@storybook/react';
import { typography } from '@rotaviva/design-tokens';

function Type() {
  return (
    <div>
      <p style={{ fontFamily: typography.display, fontSize: 28 }}>Display · Sora 28px</p>
      <p style={{ fontFamily: typography.ui, fontSize: 16 }}>UI · Manrope 16px</p>
      <p style={{ fontFamily: typography.ui, fontSize: 14 }}>UI · Manrope 14px</p>
      <p style={{ fontFamily: typography.ui, fontSize: 12 }}>UI · Manrope 12px</p>
    </div>
  );
}

const meta: Meta<typeof Type> = {
  title: 'Fundamentos/Tipografia',
  component: Type,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof Type> = {};
