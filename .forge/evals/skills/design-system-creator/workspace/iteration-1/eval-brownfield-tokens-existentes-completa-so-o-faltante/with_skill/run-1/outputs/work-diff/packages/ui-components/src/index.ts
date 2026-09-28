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

// Re-exporta ícones/mark do pacote de icons — nunca importar lucide-react direto num app.
export { Icon, RotavivaMark } from '@rotaviva/icons';
export type { IconProps, IconSize, RotavivaMarkProps, RotavivaMarkVariant } from '@rotaviva/icons';

// `patterns/` (composições de telas) é intencionalmente NÃO exportado aqui —
// vive só no Storybook, categoria "Padrões".
