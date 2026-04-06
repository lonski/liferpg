import { db } from "../firebase";
import { collection, getDocs, query, where } from "firebase/firestore";
import { useEffect } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "./useAuth";

export const useCharacters = () => {
  const [user, authLoading] = useAuth();
  const queryClient = useQueryClient();
  const queryResult = useQuery({
    queryKey: ["characters", user],
    queryFn: async () => {
      if (!user) {
        return undefined;
      }
      const c = collection(db, "characters");
      const q = user.admin ? query(c) : query(c, where("email", "==", user.email));

      return getDocs(q).then((r) => r.docs.map((d) => ({ ...d.data(), id: d.id })));
    },
  });

  useEffect(() => {
    queryClient.invalidateQueries({ queryKey: ["characters"] });
  }, [user, queryClient]);

  return [queryResult.data, authLoading || queryResult.isLoading, user];
};
