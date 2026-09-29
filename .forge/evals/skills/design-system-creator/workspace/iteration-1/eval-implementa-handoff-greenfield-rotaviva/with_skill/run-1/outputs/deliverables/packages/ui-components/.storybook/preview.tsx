import type { Preview } from '@storybook/react';
import '@rotaviva/design-tokens/css';
import './storybook.css';

const preview: Preview = {
  parameters: {
    backgrounds: {
      default: 'claro',
      values: [{ name: 'claro', value: 'var(--surface)' }],
    },
    a11y: {
      config: { rules: [{ id: 'color-contrast', enabled: true }] },
    },
    options: {
      storySort: {
        order: ['Fundamentos', ['Introdução', 'Cores', 'Tipografia', 'Espaçamento', 'Raios e Sombras', 'Motion', 'Iconografia'], 'Componentes', 'Blocos', 'Padrões'],
      },
    },
  },
  tags: ['autodocs'],
};

export default preview;
