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
import { useCharacters } from "hooks/useCharacters";
import LogoutIcon from "@mui/icons-material/Logout";

export const Home = () => {
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/login"));
  };
  const [characters, loading, user] = useCharacters();

  return (
    <>
      <AppBar position="static">
        <Toolbar variant="dense">
          <>
            {loading && <CircularProgress color="info" size={24} />}
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
          {characters && (
            <>
              {characters
                .filter((c) => c !== undefined)
                .map((c) => (
                  <Character key={c.id} character={c} user={user} />
                ))}
            </>
          )}
        </>
      </Container>
    </>
  );
};
