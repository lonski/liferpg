import React, { useState } from "react";
import { IconButton, LinearProgress } from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import { EditCharacterDialog } from "components/EditCharacterDialog/EditCharacterDialog";
import PropTypes from "prop-types";
import styles from "./Character.module.css";
import { FEATURE_FAVOUR } from "featureFlags";

const FavourEmoji = ({ favour }) => {
  if (favour < -1) return <span>😠</span>;
  if (favour === -1) return <span>😕</span>;
  if (favour > 0) return <span>😊</span>;
  return <span>😐</span>;
};

FavourEmoji.propTypes = { favour: PropTypes.number };

export const Character = ({ character, user }) => {
  const [edit, setEdit] = useState(false);
  const [badgeVisible, setBadgeVisible] = useState(false);

  if (!character) return null;

  const favour = character?.favour ?? 0;
  const xpPercent = character.level != null
    ? Math.min((character.current_xp * 100) / character.next_level_xp, 100)
    : 0;
  const xpRemaining = character.next_level_xp - character.current_xp;

  return (
    <div className={styles.card}>
      {/* Top band */}
      <div className={styles.topBand}>
        <span className={styles.bandLabel}>✦ Karta Postaci ✦</span>
        {user?.admin && (
          <IconButton
            aria-label="edytuj postać"
            size="small"
            className={styles.editIconBtn}
            onClick={() => setEdit(true)}
          >
            <EditIcon fontSize="small" />
          </IconButton>
        )}
      </div>

      {/* Body */}
      <div className={styles.body}>
        <div className={styles.innerFrame}>
          <span className={`${styles.cornerOrnament} ${styles.cornerTL}`}>❧</span>
          <span className={`${styles.cornerOrnament} ${styles.cornerTR}`}>❧</span>

          {/* Name + class */}
          <div className={styles.nameBlock}>
            <span className={styles.characterName}>{character.name}</span>
            {character.clazz && (
              <span className={styles.characterClass}>{character.clazz}</span>
            )}
          </div>

          {/* Divider */}
          <div className={styles.divider}>
            <span className={`${styles.dividerLine} ${styles.dividerLineLeft}`} />
            <span className={styles.dividerGlyph}>✦</span>
            <span className={`${styles.dividerLine} ${styles.dividerLineRight}`} />
          </div>

          {/* Level + XP */}
          {character.level != null && (
            <>
              <div className={styles.levelRow}>
                <span className={styles.statLabel}>Poziom</span>
                <span className={styles.levelBadge}>{character.level}</span>
              </div>
              <div className={styles.xpSection}>
                <div className={styles.xpMeta}>
                  <span>Doświadczenie</span>
                  <span>{character.current_xp} / {character.next_level_xp} XP</span>
                </div>
                <div
                  className={styles.xpBarWrapper}
                  onClick={() => setBadgeVisible((prev) => !prev)}
                >
                  <LinearProgress variant="determinate" value={xpPercent} />
                </div>
                {badgeVisible && (
                  <div style={{ textAlign: 'center' }}>
                    <span className={styles.xpHint}>
                      Do następnego poziomu: <strong>{xpRemaining}</strong> XP
                    </span>
                  </div>
                )}
              </div>
            </>
          )}

          {/* Gold */}
          {character.gold && (
            <div className={styles.goldRow}>
              <span className={styles.statLabel}>Złoto&nbsp; </span>
              <span className={styles.goldValue}>{character.gold} zł</span>
              {character.gold_usd != null && (
                <>
                  <span className={styles.goldSeparator}>·</span>
                  <span className={styles.goldValue}>{character.gold_usd} $</span>
                </>
              )}
            </div>
          )}

          {/* Favour (feature-flagged) */}
          {FEATURE_FAVOUR && (
            <div style={{ textAlign: 'center', marginBottom: 8 }}>
              <FavourEmoji favour={favour} />
            </div>
          )}

          {/* Traits */}
          {character.traits?.length > 0 && (
            <>
              <div className={styles.traitsDivider}>
                <span className={styles.traitsDividerLineLeft} />
                <span className={styles.traitsDividerLabel}>Cechy</span>
                <span className={styles.traitsDividerLineRight} />
              </div>
              <div className={styles.traitPills}>
                {character.traits.map((trait, index) => (
                  <div key={index} className={styles.traitPill}>
                    <span className={styles.traitName}>{trait.name}</span>
                    <span className={styles.traitValue}>{trait.value}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Bottom band */}
      <div className={styles.bottomBand}>— ✦ —</div>

      {/* Edit dialog */}
      {user?.admin && (
        <EditCharacterDialog
          charToEdit={character}
          open={edit}
          handleClose={() => setEdit(false)}
        />
      )}
    </div>
  );
};

Character.propTypes = {
  character: PropTypes.object,
  user: PropTypes.object,
};
