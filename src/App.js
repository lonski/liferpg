import { Box } from "@mui/material";
import "./App.css";
import { Home } from "./components/Home/Home";
import { Login } from "./components/Login/Login";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import React from "react";

function App() {
  const router = createBrowserRouter([
    {
      path: "/",
      element: <Home />,
    },
    {
      path: "/login",
      element: <Login />,
    },
  ]);

  return (
    <Box className="app">
      <RouterProvider router={router} />
    </Box>
  );
}

export default App;
