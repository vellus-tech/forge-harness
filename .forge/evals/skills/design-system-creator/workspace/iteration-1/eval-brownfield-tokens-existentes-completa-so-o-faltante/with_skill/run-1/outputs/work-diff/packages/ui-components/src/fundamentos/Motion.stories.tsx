import type { Meta, StoryObj } from '@storybook/react';
import { Button } from '../components/Button/Button.js';

function Motion() {
  return (
    <div>
      <p>
        <code>--dur-fast: 120ms</code>, <code>--dur-base: 200ms</code>,{' '}
        <code>--ease-out: cubic-bezier(0.2, 0.8, 0.2, 1)</code>.
      </p>
      <p>Press mecânico (scale 0.96) — experimente clicar:</p>
      <Button variant="primary">Recarregar</Button>
    </div>
  );
}

const meta: Meta<typeof Motion> = {
  title: 'Fundamentos/Motion',
  component: Motion,
  tags: ['autodocs'],
};
export default meta;

export const Default: StoryObj<typeof Motion> = {};
