import { Box, Button, Dialog, Input, Typography } from "@mui/material";
import React, { useState } from "react";

import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";

export const EditCharacterDialog = ({
  charToEdit,
  open,
  handleClose,
  handleRefresh,
}) => {
  const [character, setCharacter] = useState(charToEdit);
  const handleSave = async () => {
    const charDoc = doc(db, "characters", character.id);
    await updateDoc(charDoc, character).then(handleRefresh).then(handleClose);
  };

  return (
    <div>
      {character && (
        <Dialog onClose={handleClose} open={open}>
          <Box sx={{ margin: "10px", padding: "10px" }}>
            <Box
              display="flex"
              justifyContent="space-between"
              alignItems={"center"}
            >
              <Box sx={{ width: "90px" }}>
                <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                  Poziom:
                </Typography>
              </Box>
              <Box sx={{ marginLeft: "8px", width: "64px" }}>
                <Input
                  type={"number"}
                  value={character.level}
                  onChange={(e) => {
                    setCharacter((prev) => ({
                      ...prev,
                      level: e.target.value,
                    }));
                  }}
                />
              </Box>
            </Box>

            <Box
              display="flex"
              justifyContent="space-between"
              alignItems={"center"}
            >
              <Box sx={{ width: "90px" }}>
                <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                  XP:
                </Typography>
              </Box>
              <Box sx={{ marginLeft: "8px", width: "64px" }}>
                <Input
                  type={"number"}
                  value={character.current_xp}
                  onChange={(e) => {
                    setCharacter((prev) => ({
                      ...prev,
                      current_xp: e.target.value,
                    }));
                  }}
                />
              </Box>
              /
              <Box sx={{ marginLeft: "8px", width: "64px" }}>
                <Input
                  type={"number"}
                  value={character.next_level_xp}
                  onChange={(e) => {
                    setCharacter((prev) => ({
                      ...prev,
                      next_level_xp: e.target.value,
                    }));
                  }}
                />
              </Box>
            </Box>

            <Box
              display="flex"
              justifyContent="space-between"
              alignItems={"center"}
            >
              <Box sx={{ width: "90px" }}>
                <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                  Złoto:
                </Typography>
              </Box>
              <Box sx={{ marginLeft: "8px", width: "64px" }}>
                <Input
                  type={"number"}
                  value={character.gold}
                  onChange={(e) => {
                    setCharacter((prev) => ({
                      ...prev,
                      gold: e.target.value,
                    }));
                  }}
                />
              </Box>
            </Box>

            <Box
              sx={{ marginTop: "12px" }}
              display="flex"
              justifyContent="space-between"
              alignItems={"center"}
            >
              <Button color="primary" onClick={handleSave}>
                Zapisz
              </Button>
              <Button color="secondary" onClick={handleClose}>
                Anuluj
              </Button>
            </Box>
          </Box>
        </Dialog>
      )}
    </div>
  );
};
