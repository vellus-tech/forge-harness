import type { Meta, StoryObj } from '@storybook/react';

const meta: Meta = {
  title: 'Fundamentos/Introdução',
  tags: ['autodocs'],
  parameters: {
    docs: {
      description: {
        component:
          'Rotaviva é uma carteira de mobilidade urbana: recarga de passe, extrato de viagens e atalhos. ' +
          'Marca verde-petróleo, neutros frios, grade de 4 pt, raios generosos, sombras suaves. ' +
          'Tipografia display Sora / UI Manrope. Apenas tema claro nesta versão. ' +
          'Ver `docs/product/design-system/design-system.md` para o documento completo.',
      },
    },
  },
};
export default meta;

export const Página: StoryObj = { render: () => null };
