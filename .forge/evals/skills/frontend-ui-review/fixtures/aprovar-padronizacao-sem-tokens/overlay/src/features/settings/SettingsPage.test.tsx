import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { SettingsPage } from './SettingsPage';

describe('SettingsPage', () => {
  it('renderiza', () => { render(<SettingsPage />); expect(screen.getByText('Configurações')).toBeInTheDocument(); });
  it('aplica a classe do card', () => { const { container } = render(<SettingsPage />); expect(container.firstChild).toHaveClass('settings-card'); });
  it('aplica a classe do título', () => { render(<SettingsPage />); expect(screen.getByText('Configurações')).toHaveClass('settings-title'); });
});
