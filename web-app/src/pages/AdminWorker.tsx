// src/components/AdminWorkers.tsx
import { useEffect, useState } from "react";
import { createUserWithEmailAndPassword } from "firebase/auth";
import {
  collection,
  doc,
  getDocs,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { auth, db } from "../lib/firebase.config";
import { type UserData } from "../types";

const AdminWorkers: React.FC = () => {

  const [workers, setWorkers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingUser, setEditingUser] = useState<UserData | null>(null);
  const [formData, setFormData] = useState({
    fullName: "",
    email: "",
    dni: "",
    password: "",
  });

  // Cargar trabajadores desde Firestore
  const fetchWorkers = async () => {
    setLoading(true);
    const snapshot = await getDocs(collection(db, "users"));
    const list: UserData[] = snapshot.docs.map((docSnap) => docSnap.data() as UserData);
    setWorkers(list);
    setLoading(false);
  };

  useEffect(() => {
    fetchWorkers();
  }, []);

  // Manejar cambios en formulario
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  // Añadir trabajador
  const handleAddWorker = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      // Crear en Firebase Auth
      const userCred = await createUserWithEmailAndPassword(
        auth,
        formData.email,
        formData.password
      );

      const newUser: UserData = {
        uid: userCred.user.uid,
        role: "worker",
        email: formData.email,
        dni: formData.dni,
        fullName: formData.fullName,
        assignedWorksiteId: null,
        isActive: true,
      };

      // Guardar en Firestore
      await setDoc(doc(db, "users", newUser.uid), newUser);

      setFormData({ fullName: "", email: "", dni: "", password: "" });
      fetchWorkers();
    } catch (err) {
      console.error("Error creando trabajador", err);
    }
  };

  // Editar trabajador existente
  const handleEditWorker = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUser) return;

    try {
      await updateDoc(doc(db, "users", editingUser.uid), {
        fullName: formData.fullName,
        dni: formData.dni,
        email: formData.email,
      });

      setEditingUser(null);
      setFormData({ fullName: "", email: "", dni: "", password: "" });
      fetchWorkers();
    } catch (err) {
      console.error("Error editando trabajador", err);
    }
  };

  const startEdit = (user: UserData) => {
    setEditingUser(user);
    setFormData({
      fullName: user.fullName,
      email: user.email,
      dni: user.dni,
      password: "",
    });
  };

  return (
    <div style={{ padding: "20px" }}>
      <h2>Gestión de Trabajadores</h2>

      {/* Formulario */}
      <form
        onSubmit={editingUser ? handleEditWorker : handleAddWorker}
        style={{ marginBottom: "20px" }}
      >
        <input
          type="text"
          name="fullName"
          placeholder="Nombre completo"
          value={formData.fullName}
          onChange={handleChange}
          required
        />
        <input
          type="text"
          name="dni"
          placeholder="DNI"
          value={formData.dni}
          onChange={handleChange}
          required
        />
        <input
          type="email"
          name="email"
          placeholder="Correo"
          value={formData.email}
          onChange={handleChange}
          required
        />
        {!editingUser && (
          <input
            type="password"
            name="password"
            placeholder="Contraseña inicial"
            value={formData.password}
            onChange={handleChange}
            required
          />
        )}
        <button type="submit">
          {editingUser ? "Guardar Cambios" : "Añadir Trabajador"}
        </button>
        {editingUser && (
          <button type="button" onClick={() => setEditingUser(null)}>
            Cancelar
          </button>
        )}
      </form>

      {/* Tabla de trabajadores */}
      {loading ? (
        <p>Cargando...</p>
      ) : (
        <table border={1} cellPadding={8} style={{ width: "100%" }}>
          <thead>
            <tr>
              <th>Nombre</th>
              <th>DNI</th>
              <th>Email</th>
              <th>Activo</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {workers.map((w) => (
              <tr key={w.uid}>
                <td>{w.fullName}</td>
                <td>{w.dni}</td>
                <td>{w.email}</td>
                <td>{w.isActive ? "Sí" : "No"}</td>
                <td>
                  <button onClick={() => startEdit(w)}>Editar</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};

export default AdminWorkers;
