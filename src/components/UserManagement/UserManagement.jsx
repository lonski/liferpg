import { Alert, Box, Button, CircularProgress, Dialog, Typography, Switch } from "@mui/material";
import React from "react";
import PropTypes from "prop-types";
import { useUsers } from "hooks/useUsers";

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

const switchSx = {
  '& .MuiSwitch-switchBase.Mui-checked': { color: '#7a1414' },
  '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
    backgroundColor: '#7a1414',
  },
};

const fieldLabelStyle = {
  fontFamily: "'Cinzel', serif",
  fontSize: '9px',
  letterSpacing: '2px',
  color: '#6b1a1a',
  textTransform: 'uppercase',
};

export const UserManagement = ({ open, handleClose }) => {
  const { users, loading, fetchError, updateUserFlags, isUpdating, updateError } = useUsers();

  if (loading) {
    return (
      <Dialog open={open} onClose={handleClose}>
        <Box
          sx={{
            background: 'radial-gradient(ellipse at 50% 0%, #f5e8d0 0%, #e0ccaa 60%, #c8b080 100%)',
            border: '2px solid #6b1a1a',
            borderRadius: '4px',
            p: 6,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <CircularProgress sx={{ color: '#7a1414' }} />
        </Box>
      </Dialog>
    );
  }

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
      <Box
        sx={{
          background: 'radial-gradient(ellipse at 50% 0%, #f5e8d0 0%, #e0ccaa 60%, #c8b080 100%)',
          border: '2px solid #6b1a1a',
          borderRadius: '4px',
          overflow: 'hidden',
          boxShadow: '0 8px 32px rgba(0,0,0,0.7)',
          minWidth: 320,
        }}
      >
        <Box sx={bandStyle}>
          <span style={bandLabelStyle}>✦ Zarządzanie Użytkownikami ✦</span>
        </Box>

        <Box sx={{ p: 2 }}>
          <Box
            sx={{
              position: 'relative',
              border: '1px solid rgba(107,26,26,0.35)',
              borderRadius: '2px',
              p: '12px',
            }}
          >
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

            {(!users || users.length === 0) && (
              <Typography
                sx={{
                  fontFamily: "'Cinzel',serif",
                  fontSize: 12,
                  color: '#6b1a1a',
                  textAlign: 'center',
                  py: 2,
                }}
              >
                Brak użytkowników
              </Typography>
            )}

            {users?.map((u) => (
              <Box
                key={u.id}
                sx={{
                  mb: 1.5,
                  pb: 1.5,
                  borderBottom: '1px solid rgba(107,26,26,0.2)',
                  '&:last-child': { mb: 0, pb: 0, borderBottom: 'none' },
                }}
              >
                <Typography
                  sx={{
                    fontFamily: "'Cinzel',serif",
                    fontSize: 14,
                    fontWeight: 700,
                    color: '#2d0a0a',
                    letterSpacing: 1,
                    mb: 0.25,
                  }}
                >
                  {u.name || 'Bez nazwy'}
                </Typography>
                <Typography
                  sx={{
                    fontSize: 10,
                    color: '#6b1a1a',
                    mb: 1,
                  }}
                >
                  {u.email}
                </Typography>
                <Box display="flex" gap={3}>
                  <Box display="flex" alignItems="center" gap={0.75}>
                    <Switch
                      size="small"
                      checked={u.admin || false}
                      disabled={isUpdating}
                      onChange={(e) => updateUserFlags(u.id, { admin: e.target.checked })}
                      sx={switchSx}
                    />
                    <Typography sx={fieldLabelStyle}>Admin</Typography>
                  </Box>
                  <Box display="flex" alignItems="center" gap={0.75}>
                    <Switch
                      size="small"
                      checked={u.readOnlyOthers || false}
                      disabled={isUpdating}
                      onChange={(e) => updateUserFlags(u.id, { readOnlyOthers: e.target.checked })}
                      sx={switchSx}
                    />
                    <Typography sx={fieldLabelStyle}>Tylko do odczytu</Typography>
                  </Box>
                </Box>
              </Box>
            ))}
          </Box>
        </Box>

        {fetchError && (
          <Alert severity="error" sx={{ mx: 2, mb: 1, fontSize: 11 }}>
            Błąd pobierania: {fetchError.message}
          </Alert>
        )}
        {updateError && (
          <Alert severity="error" sx={{ mx: 2, mb: 1, fontSize: 11 }}>
            {updateError.message}
          </Alert>
        )}

        <Box
          sx={{
            ...bandStyle,
            display: 'flex',
            justifyContent: 'flex-end',
          }}
        >
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
            Zamknij
          </Button>
        </Box>
      </Box>
    </Dialog>
  );
};

UserManagement.propTypes = {
  open: PropTypes.bool.isRequired,
  handleClose: PropTypes.func.isRequired,
};
