import { useEffect, useState } from "react";
import { db } from "../firebase";
import { collection, getDocs, query, where } from "firebase/firestore";

export const useCharacters = (user) => {
  const [characters, setCharacters] = useState(null);
  const [loading, setLoading] = useState(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const handleRefresh = () => {};

  useEffect(() => {
    if (!user) {
      return;
    }
    const c = collection(db, "characters");
    const q = user.admin
      ? query(c)
      : query(c, where("email", "==", user.email));
    getDocs(q)
      .then((r) => {
        const chars = r.docs.map((d) => ({ ...d.data(), id: d.id }));
        return setCharacters(chars);
      })
      .then(() => setLoading(false));
  }, [user, handleRefresh]);

  return [characters, loading];
};
