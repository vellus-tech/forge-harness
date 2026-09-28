import type { Meta, StoryObj } from '@storybook/react';
import { motion } from '@rotaviva/design-tokens';
import { Button } from '../src/components/Button/Button.js';

const meta: Meta = {
  title: 'Fundamentos/Motion',
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj;

export const PressMecanico: Story = {
  render: () => (
    <div style={{ fontFamily: 'var(--font-ui)' }}>
      <p>
        Easing <code>{motion.easeOut}</code>, duração rápida <code>{motion.durationFast}</code>{' '}
        (press de botão), duração base <code>{motion.durationBase}</code>.
      </p>
      <Button>Pressione (scale 0.96)</Button>
    </div>
  ),
};
