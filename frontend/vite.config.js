import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
  //   https: {
  //   key: fs.readFileSync(path.resolve(__dirname, '../ssl/node-selfsigned.key')),
  //   cert: fs.readFileSync(path.resolve(__dirname, '../ssl/node-selfsigned.pem')),
  // },   
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': 'http://localhost:3001' // my Node backend
    }
  }
});
