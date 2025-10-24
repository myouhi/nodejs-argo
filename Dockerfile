# 使用官方 Node.js 轻量镜像
FROM node:20-alpine

# 设置工作目录
WORKDIR /app

# 复制依赖文件并安装
COPY package*.json ./
RUN npm install --production

# 复制项目文件
COPY index.js ./
COPY public/ ./public/
COPY tmp/ ./tmp/

# 设置启动命令
CMD ["node", "index.js"]
