import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    primary: { main: '#7a1414', dark: '#3a0a0a' },
    background: { default: '#1a1008', paper: '#e0ccaa' },
    text: { primary: '#1a0a0a' },
  },
  typography: {
    fontFamily: "'Libre Baskerville', Georgia, serif",
    h1: { fontFamily: "'Cinzel', serif" },
    h2: { fontFamily: "'Cinzel', serif" },
    h3: { fontFamily: "'Cinzel', serif" },
    h4: { fontFamily: "'Cinzel', serif" },
    overline: { fontFamily: "'Cinzel', serif", letterSpacing: '3px' },
  },
  components: {
    MuiLinearProgress: {
      styleOverrides: {
        root: {
          backgroundColor: 'rgba(107,26,26,0.12)',
          border: '1px solid rgba(107,26,26,0.35)',
          borderRadius: 2,
          height: 8,
        },
        bar: {
          background: 'linear-gradient(90deg, #6b1a1a, #c8860a)',
          borderRadius: 2,
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontFamily: "'Libre Baskerville', Georgia, serif",
          color: '#1a0a0a',
          borderColor: 'rgba(107,26,26,0.4)',
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        containedPrimary: {
          background: 'linear-gradient(135deg, #3a0a0a, #6b1a1a)',
          border: '1px solid rgba(200,134,10,0.5)',
          color: '#f5e8d0',
          '&:hover': { background: 'linear-gradient(135deg, #4a1010, #8b2020)' },
        },
        outlinedPrimary: {
          borderColor: 'rgba(107,26,26,0.5)',
          color: '#1a0a0a',
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          background: 'transparent',
          boxShadow: 'none',
          overflow: 'visible',
          margin: 16,
        },
      },
    },
    MuiInput: {
      styleOverrides: {
        underline: {
          '&:before': { borderBottomColor: 'rgba(107,26,26,0.4)' },
          '&:hover:not(.Mui-disabled):before': { borderBottomColor: '#7a1414' },
        },
      },
    },
  },
});

export default theme;
