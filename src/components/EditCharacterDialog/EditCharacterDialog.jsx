import { Autocomplete, Box, Button, Dialog, Divider, IconButton, Input, TextField, Typography } from "@mui/material";
import DeleteIcon from "@mui/icons-material/Delete";
import AddIcon from "@mui/icons-material/Add";
import React, { useEffect, useMemo, useState } from "react";
import PropTypes from "prop-types";

import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";
import { useQueryClient } from "@tanstack/react-query";
import { FEATURE_FAVOUR } from "../../featureFlags";

export const EditCharacterDialog = ({
  charToEdit,
  open,
  handleClose,
}) => {
  const queryClient = useQueryClient();
  const allCharacters = queryClient
    .getQueriesData({ queryKey: ["characters"] })
    .flatMap(([, data]) => (data || []));
  const existingTraitNames = useMemo(
    () => [...new Set(allCharacters.flatMap((c) => (c.traits || []).map((t) => t.name)))],
    [open] // eslint-disable-line
  );
  const [character, setCharacter] = useState(charToEdit);
  useEffect(() => {
    if (open) setCharacter(charToEdit);
  }, [open, charToEdit]);
  const [newTraitName, setNewTraitName] = useState('');
  const [newTraitValue, setNewTraitValue] = useState('');
  const handleSave = async () => {
    try {
      const charDoc = doc(db, "characters", character.id);
      await updateDoc(charDoc, character);
      await queryClient.invalidateQueries({ queryKey: ["characters"] });
      handleClose();
    } catch (err) {
      console.error(err);
      alert(err.message);
    }
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
                      level: Number(e.target.value),
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
                      current_xp: Number(e.target.value),
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
                      next_level_xp: Number(e.target.value),
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
                      gold: Number(e.target.value),
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
                      gold_usd: Number(e.target.value),
                    }));
                  }}
                />
              </Box>
            </Box>

            {FEATURE_FAVOUR && (
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
            )}

            <Divider sx={{ my: 1 }} />
            <Typography color={"black"} sx={{ marginLeft: "4px", mb: 1 }}>
              Cechy:
            </Typography>
            {(character.traits || []).map((trait, index) => (
              <Box
                key={index}
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
                    setCharacter((prev) => ({
                      ...prev,
                      traits: prev.traits.map((t, i) =>
                        i === index ? { ...t, value } : t
                      ),
                    }));
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

            <Box display="flex" alignItems="flex-end" gap={1} sx={{ mt: 1 }}>
              <Autocomplete
                freeSolo
                options={existingTraitNames}
                value={newTraitName}
                onChange={(e, value) => setNewTraitName(value || '')}
                onInputChange={(e, value) => setNewTraitName(value || '')}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    variant="standard"
                    placeholder="Nowa cecha..."
                    size="small"
                  />
                )}
                size="small"
                sx={{ flex: 1 }}
              />
              <Input
                value={newTraitValue}
                onChange={(e) => setNewTraitValue(e.target.value)}
                placeholder="Wartość"
                sx={{ width: "64px" }}
              />
              <IconButton
                aria-label="dodaj cechę"
                size="small"
                disabled={!newTraitName.trim()}
                onClick={() => {
                  setCharacter((prev) => ({
                    ...prev,
                    traits: [
                      ...(prev.traits || []),
                      { name: newTraitName.trim(), value: newTraitValue },
                    ],
                  }));
                  setNewTraitName('');
                  setNewTraitValue('');
                }}
              >
                <AddIcon fontSize="small" />
              </IconButton>
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

EditCharacterDialog.propTypes = {
  charToEdit: PropTypes.object,
  open: PropTypes.bool,
  handleClose: PropTypes.func,
};
