import {
  Autocomplete,
  Box,
  Button,
  Dialog,
  IconButton,
  Input,
  TextField,
  Typography,
} from "@mui/material";
import DeleteIcon from "@mui/icons-material/Delete";
import AddIcon from "@mui/icons-material/Add";
import React, { useEffect, useMemo, useState } from "react";
import PropTypes from "prop-types";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../firebase";
import { useQueryClient } from "@tanstack/react-query";
import { FEATURE_FAVOUR } from "../../featureFlags";

const bandStyle = {
  background: 'linear-gradient(90deg, #3a0a0a, #7a1414, #3a0a0a)',
  padding: '7px 16px',
  textAlign: 'center',
};

const bandLabelStyle = {
  fontFamily: "'Cinzel', serif",
  fontSize: '8px',
  letterSpacing: '4px',
  color: 'rgba(245,232,208,0.85)',
  textTransform: 'uppercase',
};

const fieldLabelStyle = {
  fontFamily: "'Cinzel', serif",
  fontSize: '9px',
  letterSpacing: '2px',
  color: '#6b1a1a',
  textTransform: 'uppercase',
  minWidth: 90,
};

const inputSx = {
  width: 64,
  '& .MuiInput-underline:before': { borderBottomColor: 'rgba(107,26,26,0.4)' },
};

export const EditCharacterDialog = ({ charToEdit, open, handleClose }) => {
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

  if (!character) return null;

  return (
    <Dialog
      onClose={handleClose}
      open={open}
      PaperProps={{
        sx: {
          background: 'transparent',
          boxShadow: 'none',
          overflow: 'visible',
          m: 2,
        },
      }}
    >
      {/* Card wrapper */}
      <Box
        sx={{
          background: 'radial-gradient(ellipse at 50% 0%, #f5e8d0 0%, #e0ccaa 60%, #c8b080 100%)',
          border: '2px solid #6b1a1a',
          borderRadius: '4px',
          overflow: 'hidden',
          boxShadow: '0 8px 32px rgba(0,0,0,0.7)',
          minWidth: 280,
        }}
      >
        {/* Top band */}
        <Box sx={bandStyle}>
          <span style={bandLabelStyle}>✦ Edycja Postaci ✦</span>
        </Box>

        {/* Body */}
        <Box sx={{ p: 2 }}>
          <Box
            sx={{
              position: 'relative',
              border: '1px solid rgba(107,26,26,0.35)',
              borderRadius: '2px',
              p: '12px',
            }}
          >
            {/* Corner ornaments */}
            <Box
              component="span"
              sx={{
                position: 'absolute',
                top: 5,
                left: 5,
                fontSize: 12,
                color: 'rgba(107,26,26,0.55)',
                lineHeight: 1,
                pointerEvents: 'none',
              }}
            >
              ❧
            </Box>
            <Box
              component="span"
              sx={{
                position: 'absolute',
                top: 5,
                right: 5,
                fontSize: 12,
                color: 'rgba(107,26,26,0.55)',
                lineHeight: 1,
                transform: 'scaleX(-1)',
                pointerEvents: 'none',
              }}
            >
              ❧
            </Box>

            {/* Character name */}
            <Typography
              sx={{
                fontFamily: "'Cinzel',serif",
                fontSize: 16,
                fontWeight: 700,
                color: '#2d0a0a',
                letterSpacing: 2,
                textAlign: 'center',
                mb: 1.5,
              }}
            >
              {character.name}
            </Typography>

            {/* Numeric fields */}
            {[
              { label: 'Poziom', key: 'level' },
              { label: 'Złoto', key: 'gold' },
              { label: 'Dolary', key: 'gold_usd' },
            ].map(({ label, key }) => (
              <Box
                key={key}
                display="flex"
                justifyContent="space-between"
                alignItems="center"
                sx={{ mb: 1 }}
              >
                <Typography sx={fieldLabelStyle}>{label}</Typography>
                <Input
                  type="number"
                  value={character[key]}
                  onChange={(e) =>
                    setCharacter((prev) => ({ ...prev, [key]: Number(e.target.value) }))
                  }
                  sx={inputSx}
                />
              </Box>
            ))}

            {/* XP row (two inputs) */}
            <Box
              display="flex"
              justifyContent="space-between"
              alignItems="center"
              sx={{ mb: 1 }}
            >
              <Typography sx={fieldLabelStyle}>XP</Typography>
              <Box display="flex" alignItems="center" gap={0.5}>
                <Input
                  type="number"
                  value={character.current_xp}
                  onChange={(e) =>
                    setCharacter((prev) => ({ ...prev, current_xp: Number(e.target.value) }))
                  }
                  sx={inputSx}
                />
                <Typography sx={{ color: '#6b1a1a', mx: 0.5 }}>/</Typography>
                <Input
                  type="number"
                  value={character.next_level_xp}
                  onChange={(e) =>
                    setCharacter((prev) => ({ ...prev, next_level_xp: Number(e.target.value) }))
                  }
                  sx={inputSx}
                />
              </Box>
            </Box>

            {/* Favour (feature-flagged) */}
            {FEATURE_FAVOUR && (
              <Box
                display="flex"
                justifyContent="space-between"
                alignItems="center"
                sx={{ mb: 1 }}
              >
                <Typography sx={fieldLabelStyle}>Przychylność</Typography>
                <Box display="flex" alignItems="center" gap={1}>
                  <Button
                    size="small"
                    onClick={() =>
                      setCharacter((prev) => ({ ...prev, favour: prev.favour - 1 }))
                    }
                  >
                    👎
                  </Button>
                  <Typography sx={{ fontWeight: 700, color: '#2d0a0a' }}>
                    {character.favour}
                  </Typography>
                  <Button
                    size="small"
                    onClick={() =>
                      setCharacter((prev) => ({ ...prev, favour: prev.favour + 1 }))
                    }
                  >
                    👍
                  </Button>
                </Box>
              </Box>
            )}

            {/* Traits divider */}
            <Box display="flex" alignItems="center" gap={0.75} sx={{ my: 1.5 }}>
              <Box
                sx={{
                  flex: 1,
                  height: 1,
                  background: 'linear-gradient(90deg, transparent, rgba(107,26,26,0.4))',
                }}
              />
              <Typography
                sx={{
                  fontFamily: "'Cinzel',serif",
                  fontSize: 8,
                  letterSpacing: 3,
                  color: '#6b1a1a',
                  textTransform: 'uppercase',
                }}
              >
                Cechy
              </Typography>
              <Box
                sx={{
                  flex: 1,
                  height: 1,
                  background: 'linear-gradient(90deg, rgba(107,26,26,0.4), transparent)',
                }}
              />
            </Box>

            {/* Existing traits */}
            {(character.traits || []).map((trait, index) => (
              <Box
                key={index}
                display="flex"
                alignItems="center"
                justifyContent="space-between"
                sx={{ mb: 0.5 }}
              >
                <Typography sx={{ flex: 1, fontSize: 11, color: '#3d1010', fontStyle: 'italic' }}>
                  {trait.name}
                </Typography>
                <Input
                  value={trait.value}
                  onChange={(e) => {
                    const value = e.target.value;
                    setCharacter((prev) => ({
                      ...prev,
                      traits: prev.traits.map((t, i) => (i === index ? { ...t, value } : t)),
                    }));
                  }}
                  sx={{ width: 64 }}
                />
                <IconButton
                  aria-label="usuń cechę"
                  size="small"
                  onClick={() =>
                    setCharacter((prev) => ({
                      ...prev,
                      traits: prev.traits.filter((_, i) => i !== index),
                    }))
                  }
                  sx={{ color: '#6b1a1a', ml: 0.5 }}
                >
                  <DeleteIcon fontSize="small" />
                </IconButton>
              </Box>
            ))}

            {/* Add new trait */}
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
                sx={{ width: 64 }}
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
                sx={{ color: '#6b1a1a' }}
              >
                <AddIcon fontSize="small" />
              </IconButton>
            </Box>
          </Box>
        </Box>

        {/* Bottom band with Save / Cancel */}
        <Box
          sx={{
            ...bandStyle,
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <Button
            onClick={handleSave}
            size="small"
            sx={{
              fontFamily: "'Cinzel',serif",
              fontSize: 9,
              letterSpacing: 2,
              color: '#f5e8d0',
              textTransform: 'uppercase',
              border: '1px solid rgba(245,232,208,0.3)',
              borderRadius: '3px',
              px: 2,
              '&:hover': { background: 'rgba(245,232,208,0.1)' },
            }}
          >
            Zapisz
          </Button>
          <Button
            onClick={handleClose}
            size="small"
            sx={{
              fontFamily: "'Cinzel',serif",
              fontSize: 9,
              letterSpacing: 2,
              color: 'rgba(245,232,208,0.5)',
              textTransform: 'uppercase',
              '&:hover': { color: '#f5e8d0' },
            }}
          >
            Anuluj
          </Button>
        </Box>
      </Box>
    </Dialog>
  );
};

EditCharacterDialog.propTypes = {
  charToEdit: PropTypes.object,
  open: PropTypes.bool,
  handleClose: PropTypes.func,
};
