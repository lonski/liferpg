import {
  AppBar,
  CircularProgress,
  Container,
  IconButton,
  Toolbar,
  Typography,
} from "@mui/material";
import LogoutIcon from "@mui/icons-material/Logout";
import AdminIcon from "@mui/icons-material/AdminPanelSettings";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { logout } from "../../firebase";
import { Character } from "components/Character/Character";
import { UserManagement } from "components/UserManagement/UserManagement";
import { useCharacters } from "hooks/useCharacters";

export const Home = () => {
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/login"));
  };
  const [characters, loading, user] = useCharacters();
  const [userManagementOpen, setUserManagementOpen] = useState(false);

  return (
    <>
      <AppBar
        position="static"
        sx={{
          background: 'linear-gradient(90deg, #280606, #4a0e0e, #280606)',
          borderBottom: '1px solid rgba(200,134,10,0.3)',
          boxShadow: '0 2px 12px rgba(0,0,0,0.6)',
        }}
      >
        <Toolbar variant="dense">
          <Typography
            variant="h6"
            sx={{
              fontFamily: "'Cinzel', serif",
              fontWeight: 700,
              letterSpacing: '3px',
              color: '#f5e8d0',
              flexGrow: 1,
            }}
          >
            ⚔&nbsp; LifeRPG
          </Typography>

          {loading ? (
            <CircularProgress size={20} sx={{ color: '#c8860a' }} />
          ) : (
            <>
              {user?.displayName && (
                <Typography
                  variant="body2"
                  sx={{
                    color: 'rgba(245,232,208,0.45)',
                    fontStyle: 'italic',
                    mr: 1,
                    fontSize: '11px',
                  }}
                >
                  {user.displayName}
                </Typography>
              )}
              {user?.admin && (
                <IconButton
                  aria-label="Zarządzaj użytkownikami"
                  onClick={() => setUserManagementOpen(true)}
                  size="small"
                  sx={{
                    color: 'rgba(245,232,208,0.6)',
                    border: '1px solid rgba(200,134,10,0.4)',
                    borderRadius: '3px',
                    padding: '4px 6px',
                    mr: 1,
                    '&:hover': { color: '#f5e8d0', borderColor: 'rgba(200,134,10,0.8)' },
                  }}
                >
                  <AdminIcon fontSize="small" />
                </IconButton>
              )}
              <IconButton
                aria-label="Wyloguj"
                onClick={handleLogout}
                size="small"
                sx={{
                  color: 'rgba(245,232,208,0.6)',
                  border: '1px solid rgba(200,134,10,0.4)',
                  borderRadius: '3px',
                  padding: '4px 6px',
                  '&:hover': { color: '#f5e8d0', borderColor: 'rgba(200,134,10,0.8)' },
                }}
              >
                <LogoutIcon fontSize="small" />
              </IconButton>
            </>
          )}
        </Toolbar>
      </AppBar>

      <Container maxWidth="xs" sx={{ py: 2 }}>
        {characters &&
          characters
            .filter((c) => c !== undefined)
            .map((c) => <Character key={c.id} character={c} user={user} />)}
      </Container>

      <UserManagement
        open={userManagementOpen}
        handleClose={() => setUserManagementOpen(false)}
      />
    </>
  );
};
