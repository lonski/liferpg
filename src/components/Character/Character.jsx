import React from "react";

export const Character = ({ character }) => {
  return (
    <div>
      {character && (
        <>
          <div>{character.name}</div>
          {character.clazz && <div>{character.clazz}</div>}
          {character.level && <div>Level: {character.level}</div>}
          {character.current_xp && (
            <div>
              XP: {character.current_xp} / {character.next_level_xp}
            </div>
          )}
          <div>Złoto: {character.gold}</div>
        </>
      )}
    </div>
  );
};
