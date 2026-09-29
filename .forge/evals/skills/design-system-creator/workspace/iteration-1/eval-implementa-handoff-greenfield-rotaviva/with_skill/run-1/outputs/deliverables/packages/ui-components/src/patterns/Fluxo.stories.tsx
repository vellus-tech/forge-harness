import { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { PhoneFrame } from './PhoneFrame/PhoneFrame.js';
import { HomeScreen } from './HomeScreen/HomeScreen.js';
import { RechargeScreen } from './RechargeScreen/RechargeScreen.js';

/**
 * Fluxo navegável Início → Recarregar → Confirmação, como descrito no
 * `ui_kits/rotaviva-app/README.md` do handoff. Renderizado dentro do
 * `PhoneFrame` — categoria Padrões, fora da API pública do pacote.
 */
function InteractiveFlow() {
  const [step, setStep] = useState<'home' | 'recharge' | 'confirmation'>('home');

  return (
    <PhoneFrame>
      {step === 'home' && <HomeScreen onRecharge={() => setStep('recharge')} />}
      {step === 'recharge' && <RechargeScreen onConfirm={() => setStep('confirmation')} />}
      {step === 'confirmation' && (
        <div style={{ padding: 'var(--s-6)', textAlign: 'center' }}>
          <p>Recarga confirmada.</p>
        </div>
      )}
    </PhoneFrame>
  );
}

const meta: Meta<typeof InteractiveFlow> = {
  title: 'Padrões/Fluxo de recarga',
  component: InteractiveFlow,
  tags: ['autodocs'],
};
export default meta;

type Story = StoryObj<typeof InteractiveFlow>;
export const Completo: Story = {};
