import { Box, Button, Dialog, Divider, IconButton, Input, Typography } from "@mui/material";
import DeleteIcon from "@mui/icons-material/Delete";
import React, { useState } from "react";
import PropTypes from "prop-types";

import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";
import { useQueryClient } from "react-query";

export const EditCharacterDialog = ({
  charToEdit,
  open,
  handleClose,
  handleRefresh,
}) => {
  const queryClient = useQueryClient();
  const [character, setCharacter] = useState(charToEdit);
  const handleSave = async () => {
    const charDoc = doc(db, "characters", character.id);
    await updateDoc(charDoc, character)
      .then(handleRefresh)
      .then(handleClose)
      .then(() => queryClient.invalidateQueries("characters"));
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
              display="flex"
              justifyContent="space-between"
              alignItems={"center"}
            >
              <Box sx={{ width: "90px" }}>
                <Typography color={"black"} sx={{ marginLeft: "4px" }}>
                  Dolary:
                </Typography>
              </Box>
              <Box sx={{ marginLeft: "8px", width: "64px" }}>
                <Input
                  type={"number"}
                  value={character.gold_usd}
                  onChange={(e) => {
                    setCharacter((prev) => ({
                      ...prev,
                      gold_usd: e.target.value,
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
                  Przychylność:
                </Typography>
              </Box>
              <Box>
                <Box
                  sx={{ marginLeft: "4px" }}
                  display="flex"
                  justifyContent="space-between"
                  alignItems="center"
                >
                  <Button
                    onClick={() => {
                      setCharacter((prev) => ({
                        ...prev,
                        favour: prev.favour - 1,
                      }));
                    }}
                  >
                    &#x1f44e;
                  </Button>
                  <Box>{character.favour}</Box>
                  <Button
                    onClick={() => {
                      setCharacter((prev) => ({
                        ...prev,
                        favour: prev.favour + 1,
                      }));
                    }}
                  >
                    &#128077;
                  </Button>
                </Box>
              </Box>
            </Box>

            <Divider sx={{ my: 1 }} />
            <Typography color={"black"} sx={{ marginLeft: "4px", mb: 1 }}>
              Cechy:
            </Typography>
            {(character.traits || []).map((trait, index) => (
              <Box
                key={trait.name}
                display="flex"
                alignItems="center"
                justifyContent="space-between"
                sx={{ mb: 0.5 }}
              >
                <Typography sx={{ flex: 1 }}>{trait.name}</Typography>
                <Input
                  value={trait.value}
                  onChange={(e) => {
                    const value = e.target.value;
                    setCharacter((prev) => {
                      const updated = [...prev.traits];
                      updated[index] = { ...updated[index], value };
                      return { ...prev, traits: updated };
                    });
                  }}
                  sx={{ width: "64px" }}
                />
                <IconButton
                  aria-label="usuń cechę"
                  size="small"
                  onClick={() => {
                    setCharacter((prev) => ({
                      ...prev,
                      traits: prev.traits.filter((_, i) => i !== index),
                    }));
                  }}
                >
                  <DeleteIcon fontSize="small" />
                </IconButton>
              </Box>
            ))}

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

EditCharacterDialog.propTypes = {
  charToEdit: PropTypes.object,
  open: PropTypes.bool,
  handleClose: PropTypes.any,
  handleRefresh: PropTypes.any,
};
