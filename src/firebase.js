import { initializeApp } from "firebase/app";
import {
  getFirestore,
  collection,
  setDoc,
  doc,
  getDoc,
} from "firebase/firestore";
import {
  GoogleAuthProvider,
  getAuth,
  signInWithPopup,
  signOut,
} from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyC4cHej7EyUJDG59yjysEhscI8D5fwJ0kY",
  authDomain: "liferpg-f3bab.firebaseapp.com",
  projectId: "liferpg-f3bab",
  storageBucket: "liferpg-f3bab.appspot.com",
  messagingSenderId: "215203057009",
  appId: "1:215203057009:web:4527c5cb002d279bc37ad0",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);

const googleProvider = new GoogleAuthProvider();
const signInWithGoogle = async () => {
  try {
    const res = await signInWithPopup(auth, googleProvider);
    const user = res.user;
    const userDoc = await getDoc(doc(db, "users", user.uid));
    if (!userDoc.exists()) {
      await setDoc(doc(collection(db, "users"), user.uid), {
        uid: user.uid,
        name: user.displayName,
        authProvider: "google",
        email: user.email,
      });
    }
  } catch (err) {
    console.error(err);
    alert(err.message);
  }
};

const logout = () => signOut(auth);

export { auth, db, signInWithGoogle, logout };
