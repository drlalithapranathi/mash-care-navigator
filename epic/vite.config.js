import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  // Relative asset paths so the build works when served from a nested OWA path
  // (…/openmrs/owa/mashmasld/) without hand-editing index.html.
  base: './',
  plugins: [react()],
  build: {
    rollupOptions: {
      input: {
        main: './index.html',
        launch: './launch.html',
      },
    },
  },
})
