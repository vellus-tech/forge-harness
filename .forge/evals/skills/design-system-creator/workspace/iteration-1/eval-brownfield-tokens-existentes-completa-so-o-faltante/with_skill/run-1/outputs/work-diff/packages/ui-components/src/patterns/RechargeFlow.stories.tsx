import { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { PhoneFrame } from './PhoneFrame.js';
import { HomeScreen } from './HomeScreen.js';
import { RechargeScreen } from './RechargeScreen.js';

type Step = 'home' | 'recharge' | 'confirmation';

function Flow() {
  const [step, setStep] = useState<Step>('home');
  return (
    <PhoneFrame>
      {step === 'home' && <HomeScreen onRecharge={() => setStep('recharge')} />}
      {step === 'recharge' && <RechargeScreen onConfirm={() => setStep('confirmation')} />}
      {step === 'confirmation' && (
        <div style={{ padding: 16 }}>
          <p>Recarga confirmada. Voltando ao início…</p>
          <button type="button" onClick={() => setStep('home')}>
            Voltar
          </button>
        </div>
      )}
    </PhoneFrame>
  );
}

const meta: Meta<typeof Flow> = {
  title: 'Padrões/Fluxo de recarga',
  component: Flow,
  tags: ['autodocs'],
  parameters: {
    docs: {
      description: {
        component:
          'Fluxo navegável Início → Recarregar → Confirmação (`ui_kits/rotaviva-app` do handoff).',
      },
    },
  },
};
export default meta;

type Story = StoryObj<typeof Flow>;

export const Interactive: Story = {};
