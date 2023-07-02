import { initializeApp } from "firebase/app"
import { getFirestore } from "firebase/firestore"

const firebaseConfig = {
    apiKey: "AIzaSyC4cHej7EyUJDG59yjysEhscI8D5fwJ0kY",
    authDomain: "liferpg-f3bab.firebaseapp.com",
    projectId: "liferpg-f3bab",
    storageBucket: "liferpg-f3bab.appspot.com",
    messagingSenderId: "215203057009",
    appId: "1:215203057009:web:4527c5cb002d279bc37ad0"
  };

const app = initializeApp(firebaseConfig)
const db = getFirestore(app)

export {db}