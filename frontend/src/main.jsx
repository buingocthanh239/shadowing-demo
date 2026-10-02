import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Link, Route, Routes } from 'react-router-dom';
import Home from './pages/Home.jsx';
import Topic from './pages/Topic.jsx';
import Lesson from './pages/Lesson.jsx';
import './styles.css';

function App() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL.replace(/\/$/, "") || "/"}>
      <header className="topbar">
        <Link to="/" className="brand">🎧 Shadowing<span>demo</span></Link>
      </header>
      <main className="container">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/topics/:topic" element={<Topic />} />
          <Route path="/topics/:topic/:lesson" element={<Lesson />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
