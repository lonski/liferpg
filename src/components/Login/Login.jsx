import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { auth, signInWithGoogle } from "../../firebase";
import { useAuthState } from "react-firebase-hooks/auth";
import { Button } from "@mui/material";
import styles from "./Login.module.css";

export const Login = () => {
  const [user, loading] = useAuthState(auth);
  const navigate = useNavigate();

  useEffect(() => {
    if (loading) return;
    if (user) navigate("/");
  }, [user, loading, navigate]);

  return (
    <div className={styles.container}>
      <div className={styles.logoMark}>
        <span className={styles.swordIcon}>⚔</span>
        <span className={styles.title}>LifeRPG</span>
        <span className={styles.subtitle}>Kronika Bohaterów</span>
        <div className={styles.divider}>
          <span className={`${styles.dividerLine} ${styles.dividerLineLeft}`} />
          <span className={styles.dividerGlyph}>✦</span>
          <span className={`${styles.dividerLine} ${styles.dividerLineRight}`} />
        </div>
      </div>

      <Button
        variant="contained"
        onClick={signInWithGoogle}
        className={styles.loginButton}
        disableElevation
        sx={{
          '&:hover': {
            background: 'linear-gradient(135deg, #4a1010, #8b2020)',
            borderColor: 'rgba(200,134,10,0.8)',
          },
        }}
      >
        <span className={styles.googleIcon} aria-hidden="true">G</span>
        <span>
          <span className={styles.loginButtonLabel}>Zaloguj przez Google</span>
          <span className={styles.loginButtonSub}>Wejdź do Kroniki</span>
        </span>
      </Button>

      <p className={styles.flavourText}>&ldquo;Twoja legenda czeka...&rdquo;</p>
    </div>
  );
};
