import { auth, db } from "../firebase";
import { doc, getDoc } from "firebase/firestore";
import { useEffect, useState } from "react";
import { useAuthState } from "react-firebase-hooks/auth";
import { useNavigate } from "react-router-dom";

export const useAuth = () => {
  const navigate = useNavigate();

  const [authUser, authLoading] = useAuthState(auth);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (authLoading) {
      return;
    }

    if (!authUser) {
      navigate("/login");
    }

    getDoc(doc(db, "users", authUser.uid))
      .then((d) => setUser(d.data()))
      .then(() => setLoading(false));
  }, [authUser, authLoading, navigate]);

  return [user, loading];
};
