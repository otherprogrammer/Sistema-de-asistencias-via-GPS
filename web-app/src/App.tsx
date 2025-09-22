import type { User } from 'firebase/auth';
import LoginComponent from './components/LoginComponent';
import './App.css';

export default function App() {
  const handleLoginSuccess = (user: User) => {
    console.log('Usuario logueado:', user.email);
  };

  const handleLogout = () => {};

  return <LoginComponent onLoginSuccess={handleLoginSuccess} onLogout={handleLogout} />;
}
