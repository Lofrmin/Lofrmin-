import { defineConfig } from 'vite';

export default defineConfig({
  build: { target: 'es2022', rollupOptions: { input: { panel: 'index.html', monitor: 'monitor.html', pet: 'pet.html' } } },
  server: {
    // 教程 Step 5 的 FastAPI 对话后端；没启动时前端自动退回本地意图
    proxy: { '/api': { target: 'http://127.0.0.1:8001', changeOrigin: true } },
  },
});
