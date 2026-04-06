import { render, screen, fireEvent } from '@testing-library/react';
import { EditCharacterDialog } from './EditCharacterDialog';

jest.mock('../../firebase', () => ({ db: {} }));
jest.mock('firebase/firestore', () => ({
  doc: jest.fn(),
  updateDoc: jest.fn(() => Promise.resolve()),
}));
jest.mock('react-query', () => ({
  useQueryClient: () => ({
    invalidateQueries: jest.fn(),
    getQueriesData: jest.fn(() => []),
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
      handleClose={jest.fn()}
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
      handleClose={jest.fn()}
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
      handleClose={jest.fn()}
    />
  );
  const deleteButtons = screen.getAllByLabelText('usuń cechę');
  fireEvent.click(deleteButtons[0]); // delete Siła
  expect(screen.queryByText('Siła')).not.toBeInTheDocument();
  expect(screen.getByText('Zręczność')).toBeInTheDocument();
});
