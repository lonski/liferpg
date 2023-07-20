import {
  AppBar,
  Box,
  CircularProgress,
  Container,
  IconButton,
  Toolbar,
} from "@mui/material";
import { logout } from "../../firebase";
import { useNavigate } from "react-router-dom";
import React from "react";
import { Character } from "components/Character/Character";
import { useAuth } from "hooks/useAuth";
import { useCharacters } from "hooks/useCharacters";
import LogoutIcon from "@mui/icons-material/Logout";

export const Home = () => {
  const [user, loading] = useAuth();
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/login"));
  };
  const [characters, charactersLoading] = useCharacters(user);

  return (
    <>
      <AppBar position="static">
        <Toolbar variant="dense">
          <>
            {(loading || charactersLoading) && (
              <CircularProgress color="info" size={24} />
            )}
            <Box sx={{ flexGrow: 1 }} />
            {loading || (
              <>
                <IconButton color="inherit" onClick={handleLogout}>
                  <LogoutIcon />
                </IconButton>
              </>
            )}
          </>
        </Toolbar>
      </AppBar>

      <Container maxWidth="xs">
        <>
          {charactersLoading || (
            <>
              {characters
                .filter((c) => c !== undefined)
                .map((c) => (
                  <Character key={c.name} character={c} user={user} />
                ))}
            </>
          )}
        </>
      </Container>
    </>
  );
};
