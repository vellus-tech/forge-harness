import { axe, type JestAxeConfigOptions } from 'jest-axe';

/**
 * Helper compartilhado de a11y para os testes de componente. jsdom não avalia
 * contraste — `color-contrast` volta como "incomplete" (não falha aqui);
 * contraste real é responsabilidade do `@storybook/addon-a11y` no browser.
 */
export async function runA11y(container: Element, options?: JestAxeConfigOptions) {
  const results = await axe(container, options);
  expect(results).toHaveNoViolations();
}
