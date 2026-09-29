import { axe, type JestAxeConfigOptions } from 'jest-axe';

/**
 * Helper de a11y para testes de componente. jsdom não avalia contraste real
 * — `color-contrast` volta como "incomplete", não como falha. Contraste real
 * só é verificado pelo `@storybook/addon-a11y` em browser (ver accessibility.md).
 */
export async function runA11y(container: Element, options?: JestAxeConfigOptions) {
  const results = await axe(container, options);
  return results;
}
