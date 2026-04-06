import { Box } from "@mui/material";
import "./App.css";
import { Home } from "./components/Home/Home";
import { Login } from "./components/Login/Login";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import React from "react";
import { QueryClient, QueryClientProvider } from "react-query";

const queryClient = new QueryClient();

const router = createBrowserRouter([
  { path: "/", element: <Home /> },
  { path: "/login", element: <Login /> },
]);

function App() {

  return (
    <QueryClientProvider client={queryClient}>
      <Box className="app">
        <RouterProvider router={router} />
      </Box>
    </QueryClientProvider>
  );
}

export default App;
