import { render, screen, fireEvent } from '@testing-library/react';
import { EditCharacterDialog } from './EditCharacterDialog';

vi.mock('../../firebase', () => ({ db: {} }));
vi.mock('firebase/firestore', () => ({
  doc: vi.fn(),
  updateDoc: vi.fn(() => Promise.resolve()),
}));
vi.mock('@tanstack/react-query', () => ({
  useQueryClient: () => ({
    invalidateQueries: vi.fn(),
    getQueriesData: vi.fn(() => []),
  }),
}));

const character = {
  id: 'c1',
  name: 'Hero',
  level: 5,
  current_xp: 100,
  next_level_xp: 200,
  gold: 30,
  gold_usd: 0,
  favour: 0,
  traits: [
    { name: 'Siła', value: '12' },
    { name: 'Zręczność', value: '8' },
  ],
};

test('renders existing traits in the dialog', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  expect(screen.getByText('Siła')).toBeInTheDocument();
  expect(screen.getByDisplayValue('12')).toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
  expect(screen.getByDisplayValue('8')).toBeInTheDocument();
});

test('editing a trait value updates local state', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const input = screen.getByDisplayValue('12');
  fireEvent.change(input, { target: { value: '15' } });
  expect(screen.getByDisplayValue('15')).toBeInTheDocument();
});

test('deleting a trait removes it from the list', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const deleteButtons = screen.getAllByLabelText('usuń cechę');
  fireEvent.click(deleteButtons[0]);
  expect(screen.queryByText('Siła')).not.toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
});

test('does not render Przychylność field by default (flag off)', () => {
  const char = { id: '1', level: 1, current_xp: 0, next_level_xp: 100, gold: 0, gold_usd: 0, favour: 2, traits: [] };
  render(<EditCharacterDialog charToEdit={char} open={true} handleClose={() => {}} />);
  expect(screen.queryByText('Przychylność:')).not.toBeInTheDocument();
});

test('adding a new trait appends it to the list', () => {
  render(
    <EditCharacterDialog
      charToEdit={character}
      open={true}
      handleClose={vi.fn()}
    />
  );
  const nameInput = screen.getByPlaceholderText('Nowa cecha...');
  fireEvent.change(nameInput, { target: { value: 'Charyzma' } });

  const valueInput = screen.getByPlaceholderText('Wartość');
  fireEvent.change(valueInput, { target: { value: 'wysoka' } });

  fireEvent.click(screen.getByLabelText('dodaj cechę'));

  expect(screen.getByText('Charyzma')).toBeInTheDocument();
  expect(screen.getByDisplayValue('wysoka')).toBeInTheDocument();
  expect(nameInput.value).toBe('');
  expect(valueInput.value).toBe('');
});
