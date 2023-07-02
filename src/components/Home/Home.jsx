import { Button } from "@mui/material";
import { logout } from "../../firebase";
import { useNavigate } from "react-router-dom";
import React from "react";

export const Home = () => {
  const navigate = useNavigate();
  const handleLogout = () => {
    logout().then(() => navigate("/"));
  };

  return (
    <div>
      Joł
      <Button onClick={handleLogout}>Logout</Button>
    </div>
  );
};
