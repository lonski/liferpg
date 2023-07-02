import { Button } from "@mui/material";
import { logout } from "../../firebase";

export const Home = () => {
  return (
    <div>
      Joł
      <Button onClick={logout}>Logout</Button>
    </div>
  );
};
