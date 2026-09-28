import { addons } from '@storybook/manager-api';
import { create } from '@storybook/theming';
import { brand } from '@rotaviva/design-tokens';

addons.setConfig({
  theme: create({
    base: 'light',
    brandTitle: 'Rotaviva Design System',
    brandUrl: '/',
    colorPrimary: brand.base,
    colorSecondary: brand.base,
  }),
});
