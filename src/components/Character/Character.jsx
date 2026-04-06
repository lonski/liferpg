import {
  Box,
  Chip,
  Divider,
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
import PropTypes from "prop-types";
import SentimentVeryDissatisfiedIcon from "@mui/icons-material/SentimentVeryDissatisfied";
import SentimentSatisfiedIcon from "@mui/icons-material/SentimentSatisfied";
import SentimentSatisfiedAltIcon from "@mui/icons-material/SentimentSatisfiedAlt";
import { SentimentDissatisfied } from "@mui/icons-material";

export const Character = ({ character, user }) => {
  const [edit, setEdit] = useState(false);
  const handleEdit = () => setEdit(true);
  const handleClose = () => setEdit(false);
  const [badgeVisible, setBadgeVisible] = useState(false);
  return (
    <div>
      {character && (
        <Paper sx={{ margin: "4px", padding: "4px" }} elevation={2}>
          <Box display="flex" justifyContent="space-between">
            <Typography variant="h4">{character.name}</Typography>
            <Box>
              <Box marginTop={"10px"} display="flex" justifyContent="left">
                {character.favour === 0 && <SentimentSatisfiedIcon />}
                {character.favour === -1 && (
                  <SentimentDissatisfied color="warning" />
                )}
                {character.favour < -1 && (
                  <SentimentVeryDissatisfiedIcon color="error" />
                )}
                {character.favour > 0 && (
                  <SentimentSatisfiedAltIcon color="success" />
                )}
              </Box>
            </Box>
          </Box>
          {character.clazz && (
            <Typography variant="overline" display="block" gutterBottom>
              {character.clazz}
            </Typography>
          )}

          {character.level && (
            <Box onClick={() => setBadgeVisible((prev) => !prev)}>
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
                {badgeVisible && (
                  <Box
                    display="flex"
                    justifyContent="center"
                    sx={{ marginTop: 1 }}
                  >
                    <Chip
                      sx={{ width: "100%" }}
                      label={
                        <span>
                          Do następnego poziomu brakuje:&nbsp;
                          <b>
                            {character.next_level_xp - character.current_xp}
                          </b>
                          &nbsp;punktów
                        </span>
                      }
                      color="success"
                      variant="outlined"
                    />
                  </Box>
                )}
              </Box>
            </Box>
          )}
          <Box display="flex" justifyContent="space-between">
            {character.gold !== undefined && (
            <Box marginTop={"10px"} display="flex" justifyContent="left">
              <WalletIcon />
              <Box color={"black"}>
                <Chip
                  sx={{ marginLeft: "4px" }}
                  size="small"
                  variant="outlined"
                  label={<span> {character.gold}zł </span>}
                  color="warning"
                />
                {character.gold_usd && (
                  <Chip
                    sx={{ marginLeft: "4px" }}
                    size="small"
                    variant="outlined"
                    label={<span> {character.gold_usd}$ </span>}
                    color="warning"
                  />
                )}
              </Box>
            </Box>
            )}
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
          {character.traits?.length > 0 && (
            <>
              <Divider sx={{ mt: 1 }} />
              <Typography
                variant="overline"
                display="block"
                sx={{ mt: 0.5, lineHeight: 1.5 }}
              >
                Cechy
              </Typography>
              {character.traits.map((trait) => (
                <Box
                  key={trait.name}
                  display="flex"
                  justifyContent="space-between"
                  alignItems="center"
                  sx={{ py: 0.25 }}
                >
                  <Typography variant="body2">{trait.name}</Typography>
                  <Chip
                    label={trait.value}
                    color="primary"
                    variant="outlined"
                    size="small"
                  />
                </Box>
              ))}
            </>
          )}
        </Paper>
      )}
    </div>
  );
};

Character.propTypes = {
  character: PropTypes.object,
  user: PropTypes.object,
};
