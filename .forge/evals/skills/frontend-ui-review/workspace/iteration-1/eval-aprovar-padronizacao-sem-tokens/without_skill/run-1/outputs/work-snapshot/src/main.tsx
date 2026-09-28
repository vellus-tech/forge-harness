import '@acme/design-tokens/tokens.css';
import { createRoot } from 'react-dom/client';
import { SettingsPage } from './features/settings/SettingsPage';
createRoot(document.getElementById('root')!).render(<SettingsPage />);
