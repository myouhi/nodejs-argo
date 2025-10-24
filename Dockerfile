# ----------------------------
# 1️⃣ Build 阶段（安装依赖）
# ----------------------------
FROM node:20-alpine AS build

# 设置工作目录
WORKDIR /app

# 复制依赖文件并安装
COPY package*.json ./
RUN npm install --production

# 复制项目文件
COPY index.js ./ 
COPY public/ ./public/
# tmp 目录如果只用于运行时，可以在最终镜像里创建，不必在 build 阶段复制
# COPY tmp/ ./tmp/

# ----------------------------
# 2️⃣ 生产阶段（最小化镜像）
# ----------------------------
FROM node:20-alpine AS production

WORKDIR /app

# 复制 build 阶段的依赖和代码
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/index.js ./index.js
COPY --from=build /app/public ./public

# 创建 tmp 目录（空目录，用于运行时）
RUN mkdir -p ./tmp

# 设置启动命令
CMD ["node", "index.js"]
