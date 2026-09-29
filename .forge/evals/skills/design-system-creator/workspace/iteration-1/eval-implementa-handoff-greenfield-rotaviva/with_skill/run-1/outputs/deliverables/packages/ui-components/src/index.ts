// Primitivos
export * from './components/Button/index.js';
export * from './components/Input/index.js';
export * from './components/Badge/index.js';
export * from './components/Card/index.js';
export * from './components/Eyebrow/index.js';

// Blocos
export * from './blocks/AppHeader/index.js';
export * from './blocks/BalanceCard/index.js';
export * from './blocks/TripRow/index.js';
export * from './blocks/ShortcutGrid/index.js';
export * from './blocks/BottomNav/index.js';

// Re-exporta ícones e mark de @rotaviva/icons
export { Icon, RotavivaMark } from '@rotaviva/icons';
export type { IconProps, IconSize, RotavivaMarkProps, RotavivaMarkVariant } from '@rotaviva/icons';

// `patterns/` NÃO é exportado aqui — é uso exclusivo do Storybook.
