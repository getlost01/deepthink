import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id: string) {
          if (!id.includes('node_modules')) return
          if (id.includes('@xyflow')) return 'chunk-xyflow'
          if (id.includes('framer-motion')) return 'chunk-framer'
          if (
            id.includes('react-markdown') ||
            id.includes('remark') ||
            id.includes('mdast') ||
            id.includes('micromark')
          ) {
            return 'chunk-markdown'
          }
          return 'chunk-vendor'
        },
      },
    },
    chunkSizeWarningLimit: 650,
  },
})
