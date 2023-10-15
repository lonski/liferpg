import { db } from "../firebase";
import { collection, getDocs, query as dupa, where } from "firebase/firestore";
import { useEffect } from "react";
import { useQuery, useQueryClient } from "react-query";
import { useAuth } from "./useAuth";

export const useCharacters = () => {
  const [user, authLoading] = useAuth();
  const queryClient = useQueryClient();
  const query = useQuery(["characters", user], async () => {
    if (!user) {
      return Promise.resolve();
    }
    const c = collection(db, "characters");
    const q = user.admin ? dupa(c) : dupa(c, where("email", "==", user.email));

    return getDocs(q).then((r) => {
      const chars = r.docs.map((d) => ({ ...d.data(), id: d.id }));
      return chars;
    });
  });

  useEffect(() => {
    queryClient.invalidateQueries("characters");
  }, [user]);

  return [query.data, authLoading || query.isLoading];
};
