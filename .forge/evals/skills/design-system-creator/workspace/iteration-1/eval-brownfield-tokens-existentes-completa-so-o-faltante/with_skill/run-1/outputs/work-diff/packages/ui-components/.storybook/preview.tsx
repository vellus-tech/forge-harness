import type { Preview } from '@storybook/react';
import '@rotaviva/design-tokens/css';
import './storybook.css';

const preview: Preview = {
  parameters: {
    backgrounds: {
      default: 'claro',
      values: [
        { name: 'claro', value: '#FFFFFF' },
        { name: 'superfície muted', value: '#F6F8F9' },
      ],
    },
    a11y: {
      config: { rules: [{ id: 'color-contrast', enabled: true }] },
    },
    options: {
      storySort: {
        order: ['Fundamentos', 'Componentes', 'Blocos', 'Padrões'],
      },
    },
  },
  tags: ['autodocs'],
};

export default preview;
