import { render, screen } from '@testing-library/react';
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
