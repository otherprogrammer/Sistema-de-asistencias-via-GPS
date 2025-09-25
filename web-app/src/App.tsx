import { AuthProvider } from './contexts/AuthContext';
import { AppRouter } from './router';
import './App.css';

export default function App() {
  return (
    <AuthProvider>
      <AppRouter />
    </AuthProvider>
  )
}
