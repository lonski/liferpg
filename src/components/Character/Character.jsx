import {
  Box,
  IconButton,
  LinearProgress,
  Paper,
  Typography,
} from "@mui/material";
import React, { useState } from "react";
import TrendingUpIcon from "@mui/icons-material/TrendingUp";
import WalletIcon from "@mui/icons-material/Wallet";
import EditIcon from "@mui/icons-material/Edit";
import { EditCharacterDialog } from "components/EditCharacterDialog/EditCharacterDialog";

export const Character = ({ character, user }) => {
  const [edit, setEdit] = useState(false);
  const handleEdit = () => setEdit(true);
  const handleClose = () => setEdit(false);

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
                  value={Math.min(
                    (character.current_xp * 100) / character.next_level_xp,
                    100
                  )}
                />
              </Box>
            </>
          )}
          <Box display="flex" justifyContent="space-between">
            <Box marginTop={"10px"} display="flex" justifyContent="left">
              <WalletIcon />
              <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                {character.gold} zł
              </Typography>
            </Box>
            {user?.admin && (
              <Box>
                <IconButton onClick={handleEdit}>
                  <EditIcon />
                </IconButton>
                <EditCharacterDialog
                  charToEdit={character}
                  open={edit}
                  handleClose={handleClose}
                />
              </Box>
            )}
          </Box>
        </Paper>
      )}
    </div>
  );
};
