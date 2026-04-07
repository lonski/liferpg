import { render } from '@testing-library/react';
import App from './App';
import theme from './theme';

test('renders without crashing', () => {
  render(<App />);
});

test('theme has burgundy primary colour', () => {
  expect(theme.palette.primary.main).toBe('#7a1414');
});

test('theme has dark warm background', () => {
  expect(theme.palette.background.default).toBe('#1a1008');
});

test('theme uses Cinzel for h4 typography', () => {
  expect(theme.typography.h4.fontFamily).toContain('Cinzel');
});
