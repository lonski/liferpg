import { Box } from "@mui/material";
import "./App.css";
import { Home } from "./components/Home/Home";
import { Login } from "./components/Login/Login";
import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import React from "react";

function App() {
  return (
    <Box className="app">
      <Router>
        <Routes>
          <Route path="/" element={<Login />} />
          <Route path="/home" element={<Home />} />
        </Routes>
      </Router>
    </Box>
  );
}

export default App;
