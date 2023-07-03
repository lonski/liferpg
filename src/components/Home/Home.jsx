import { Button, CircularProgress } from "@mui/material";
import { logout } from "../../firebase";
import { useNavigate } from "react-router-dom";
import React from "react";
import { Character } from "components/Character/Character";
import { useAuth } from "hooks/useAuth";
import { useCharacters } from "hooks/useCharacters";

export const Home = () => {
  const [user, loading] = useAuth();
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/"));
  };
  const [characters, charactersLoading] = useCharacters(user);

  return (
    <div>
      {(loading || charactersLoading) && <CircularProgress />}
      {loading || (
        <>
          <Button onClick={handleLogout}>Logout</Button>
        </>
      )}
      {charactersLoading || (
        <>
          {characters
            .filter((c) => c !== undefined)
            .map((c) => (
              <Character key={c.name} character={c} />
            ))}
        </>
      )}
    </div>
  );
};
