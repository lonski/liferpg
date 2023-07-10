import { Box, LinearProgress, Paper, Typography } from "@mui/material";
import React from "react";
import TrendingUpIcon from "@mui/icons-material/TrendingUp";
import WalletIcon from "@mui/icons-material/Wallet";

export const Character = ({ character }) => {
  return (
    <div>
      {character && (
        <Paper sx={{ margin: "4px", padding: "4px" }} elevation={2}>
          <Typography variant="h4">{character.name}</Typography>
          {character.clazz && (
            <Typography variant="overline" display="block" gutterBottom>
              {character.clazz}
            </Typography>
          )}

          {character.level && (
            <>
              <Box display="flex" justifyContent="left">
                <TrendingUpIcon />
                <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                  Poziom {character.level}
                </Typography>
              </Box>
              <Box>
                <LinearProgress
                  variant="determinate"
                  value={(character.current_xp * 100) / character.next_level_xp}
                />
              </Box>
            </>
          )}
          <div>
            <Box marginTop={"10px"} display="flex" justifyContent="left">
              <WalletIcon />
              <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                {character.gold} zł
              </Typography>
            </Box>
          </div>
        </Paper>
      )}
    </div>
  );
};
