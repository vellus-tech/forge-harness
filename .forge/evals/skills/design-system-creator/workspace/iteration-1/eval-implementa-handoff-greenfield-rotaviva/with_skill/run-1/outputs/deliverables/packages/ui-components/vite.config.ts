/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

export default defineConfig({
  plugins: [react()],
  build: {
    lib: {
      entry: fileURLToPath(new URL('./src/index.ts', import.meta.url)),
      formats: ['es'],
      fileName: 'index',
    },
    rollupOptions: {
      external: ['react', 'react-dom', 'react/jsx-runtime', '@rotaviva/design-tokens', '@rotaviva/icons'],
    },
  },
  test: {
    environment: 'jsdom',
    css: true,
    setupFiles: ['./test/setup.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/components/**', 'src/blocks/**', 'src/lib/**', 'lib/**'],
      thresholds: {
        lines: 80,
        branches: 75,
        functions: 80,
      },
    },
  },
});
