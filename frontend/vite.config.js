import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// BASE_PATH=/project/shadowing khi deploy dưới sub-path (xem docker-compose.yml)
const base = (process.env.BASE_PATH || '').replace(/\/$/, '') + '/';

export default defineConfig({
  base,
  plugins: [react()],
  server: { port: 5180 },
});
