import { ref, watchEffect } from 'vue';

export type Theme = 'light' | 'dark';

const theme = ref<Theme>('light');

watchEffect(() => {
  document.documentElement.dataset.theme = theme.value;
});

export function useTheme() {
  function toggle(): void {
    theme.value = theme.value === 'light' ? 'dark' : 'light';
  }
  return { theme, toggle };
}
