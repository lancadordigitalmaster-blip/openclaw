FROM node:current-slim

# ffmpeg para transcrição de áudio/vídeo
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3 \
    python3-pip \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar dependências primeiro (cache de build)
COPY package.json ./
RUN npm install --production

# Copiar código
COPY . .

# Volumes para persistência
VOLUME ["/app/auth_state", "/app/sessions", "/app/groups"]

# Health check a cada 30s
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3002/health || exit 1

EXPOSE 3002

CMD ["node", "bridge.js"]
