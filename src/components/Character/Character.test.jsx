import { render, screen, fireEvent } from '@testing-library/react';
import { Character } from './Character';

vi.mock('components/EditCharacterDialog/EditCharacterDialog', () => ({
  EditCharacterDialog: () => null,
}));

const base = { name: 'Hero', favour: 0 };

test('renders traits section when traits exist', () => {
  const character = {
    ...base,
    traits: [
      { name: 'Siła', value: '12' },
      { name: 'Zręczność', value: 'wysoka' },
    ],
  };
  render(<Character character={character} user={null} />);
  expect(screen.getByText('Cechy')).toBeInTheDocument();
  expect(screen.getByText('Siła')).toBeInTheDocument();
  expect(screen.getByText('12')).toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
  expect(screen.getByText('wysoka')).toBeInTheDocument();
});

test('does not render traits section when traits array is empty', () => {
  render(<Character character={{ ...base, traits: [] }} user={null} />);
  expect(screen.queryByText('Cechy')).not.toBeInTheDocument();
});

test('does not render traits section when traits field is absent', () => {
  render(<Character character={base} user={null} />);
  expect(screen.queryByText('Cechy')).not.toBeInTheDocument();
});

test('does not render favour icon by default (flag off)', () => {
  render(<Character character={{ name: 'Hero', favour: 1 }} user={null} />);
  expect(document.querySelector('[data-testid="SentimentSatisfiedAltIcon"]')).not.toBeInTheDocument();
});

test('card header shows "Karta Postaci"', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={null} />);
  expect(screen.getByText('✦ Karta Postaci ✦')).toBeInTheDocument();
});

test('edit button is not visible to non-admin users', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={{ admin: false }} />);
  expect(screen.queryByLabelText('edytuj postać')).not.toBeInTheDocument();
});

test('edit button is visible to admin users', () => {
  render(<Character character={{ name: 'Hero', favour: 0 }} user={{ admin: true }} />);
  expect(screen.getByLabelText('edytuj postać')).toBeInTheDocument();
});

test('clicking XP bar shows remaining XP hint', () => {
  const character = { name: 'Hero', favour: 0, level: 5, current_xp: 300, next_level_xp: 500 };
  render(<Character character={character} user={null} />);
  const xpBar = screen.getByRole('progressbar');
  fireEvent.click(xpBar);
  expect(screen.getByText(/200/)).toBeInTheDocument();
});
