import { Button, CircularProgress } from "@mui/material";
import { logout, auth } from "../../firebase";
import { useNavigate } from "react-router-dom";
import React, { useEffect } from "react";
import { useAuthState } from "react-firebase-hooks/auth";
import { Character } from "components/Character/Character";

export const Home = () => {
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/"));
  };
  const [user, loading] = useAuthState(auth);

  useEffect(() => {
    if (loading) return;
    if (!user) return navigate("/");
  }, [loading, navigate, user]);

  return (
    <div>
      {loading && <CircularProgress />}
      {loading || (
        <>
          <Button onClick={handleLogout}>Logout</Button>
          <Character />
        </>
      )}
    </div>
  );
};
