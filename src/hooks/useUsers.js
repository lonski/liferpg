import { db } from "../firebase";
import { collection, getDocs, updateDoc, doc } from "firebase/firestore";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "./useAuth";

export const useUsers = () => {
  const [user, authLoading] = useAuth();
  const queryClient = useQueryClient();

  const queryResult = useQuery({
    queryKey: ["users", user?.uid],
    queryFn: async () => {
      if (!user || !user.admin) {
        return [];
      }
      const c = collection(db, "users");
      const snapshot = await getDocs(c);
      return snapshot.docs.map((d) => ({ ...d.data(), id: d.id }));
    },
    enabled: !!user?.admin,
  });

  const updateUserMutation = useMutation({
    mutationFn: async ({ uid, flags }) => {
      if (!user?.admin) {
        throw new Error("Only admins can update user flags");
      }
      await updateDoc(doc(db, "users", uid), flags);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users", user?.uid] });
    },
  });

  return {
    users: queryResult.data,
    loading: authLoading || (!!user?.admin && queryResult.isPending),
    updateUserFlags: (uid, flags) => updateUserMutation.mutate({ uid, flags }),
    isUpdating: updateUserMutation.isPending,
    updateError: updateUserMutation.error,
    isAdmin: user?.admin,
  };
};
