import { Box } from "@mui/material";
import { ThemeProvider } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import "./App.css";
import { Home } from "./components/Home/Home";
import { Login } from "./components/Login/Login";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import theme from "./theme";

const queryClient = new QueryClient();

const router = createBrowserRouter([
  { path: "/", element: <Home /> },
  { path: "/login", element: <Login /> },
]);

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <Box className="app">
          <RouterProvider router={router} />
        </Box>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
