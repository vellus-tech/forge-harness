import type { Meta, StoryObj } from '@storybook/react';

const meta: Meta = {
  title: 'Fundamentos/Introdução',
  tags: ['autodocs'],
  parameters: { layout: 'padded' },
};
export default meta;

type Story = StoryObj;

export const Sobre: Story = {
  render: () => (
    <div style={{ fontFamily: 'var(--font-ui)', color: 'var(--fg)', maxWidth: 640 }}>
      <h1 style={{ fontFamily: 'var(--font-display)' }}>Rotaviva — Design System</h1>
      <p>
        Carteira de mobilidade urbana: recarga de passe, extrato de viagens e atalhos. Cor de
        marca verde-petróleo, neutros frios, grade de espaçamento de 4&nbsp;pt, raios generosos
        em cards, sombras suaves. Tipografia display Sora, UI Manrope. Apenas tema claro nesta
        versão — sem modo escuro.
      </p>
    </div>
  ),
};
