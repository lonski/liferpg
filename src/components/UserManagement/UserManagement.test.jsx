import { render, screen, fireEvent } from '@testing-library/react';
import { UserManagement } from './UserManagement';

vi.mock('hooks/useUsers', () => ({
  useUsers: vi.fn(),
}));

const mockUseUsers = await import('hooks/useUsers');

const users = [
  { id: 'u1', name: 'Jan Kowalski', email: 'jan@example.com', admin: true, readOnlyOthers: false },
  { id: 'u2', name: 'Anna Nowak', email: 'anna@example.com', admin: false, readOnlyOthers: true },
  { id: 'u3', name: 'Bez nazwy', email: 'bez@example.com', admin: false, readOnlyOthers: false },
];

const defaultHook = (overrides = {}) => ({
  users,
  loading: false,
  updateUserFlags: vi.fn(),
  isUpdating: false,
  updateError: null,
  isAdmin: true,
  ...overrides,
});

describe('UserManagement', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  test('shows loading spinner when loading', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ users: undefined, loading: true }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  test('renders user list with names and emails', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook());
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getByText('Jan Kowalski')).toBeInTheDocument();
    expect(screen.getByText('jan@example.com')).toBeInTheDocument();
    expect(screen.getByText('Anna Nowak')).toBeInTheDocument();
    expect(screen.getByText('anna@example.com')).toBeInTheDocument();
  });

  test('renders admin and readOnlyOthers switches for each user', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook());
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getAllByRole('switch').length).toBe(6);
  });

  test('shows "Brak użytkowników" when user list is empty', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ users: [] }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getByText('Brak użytkowników')).toBeInTheDocument();
  });

  test('shows "Bez nazwy" when user name is missing', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook({
      users: [{ id: 'u1', name: null, email: 'test@example.com', admin: false, readOnlyOthers: false }],
    }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getByText('Bez nazwy')).toBeInTheDocument();
  });

  test('calls updateUserFlags with only admin flag when admin switch is toggled', () => {
    const updateUserFlags = vi.fn();
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ updateUserFlags }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    const checkboxes = screen.getAllByRole('switch');
    fireEvent.click(checkboxes[0]); // user1 admin switch (currently true → false)
    expect(updateUserFlags).toHaveBeenCalledWith('u1', { admin: false });
  });

  test('calls updateUserFlags with only readOnlyOthers flag when readOnly switch is toggled', () => {
    const updateUserFlags = vi.fn();
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ updateUserFlags }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    const checkboxes = screen.getAllByRole('switch');
    fireEvent.click(checkboxes[3]); // user2 readOnlyOthers switch (currently true → false)
    expect(updateUserFlags).toHaveBeenCalledWith('u2', { readOnlyOthers: false });
  });

  test('disables all switches while an update is in progress', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ isUpdating: true }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    screen.getAllByRole('switch').forEach((cb) => expect(cb).toBeDisabled());
  });

  test('shows error message when updateError is set', () => {
    mockUseUsers.useUsers.mockReturnValue(defaultHook({ updateError: new Error('Błąd aktualizacji') }));
    render(<UserManagement open={true} handleClose={vi.fn()} />);
    expect(screen.getByText('Błąd aktualizacji')).toBeInTheDocument();
  });

  test('calls handleClose when Zamknij button is clicked', () => {
    const handleClose = vi.fn();
    mockUseUsers.useUsers.mockReturnValue(defaultHook());
    render(<UserManagement open={true} handleClose={handleClose} />);
    fireEvent.click(screen.getByText('Zamknij'));
    expect(handleClose).toHaveBeenCalled();
  });
});
