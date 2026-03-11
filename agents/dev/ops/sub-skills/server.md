# server.md — Ops Sub-Skill: Server Setup & Nginx
# Ativa quando: "servidor", "VPS", "nginx", "proxy", "domínio"

## Setup Inicial de VPS (Ubuntu 22.04)

```bash
# 1. Atualizar sistema
apt update && apt upgrade -y

# 2. Configurar timezone
timedatectl set-timezone America/Sao_Paulo

# 3. Criar usuário de deploy (não usar root)
adduser deploy
usermod -aG sudo deploy

# 4. Configurar SSH para o usuário deploy
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# 5. Desabilitar login root via SSH
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

# 6. Instalar dependências base
apt install -y git curl wget unzip htop ncdu ufw fail2ban
```

## Hardening Básico

```bash
# UFW — Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP
ufw allow 443/tcp    # HTTPS
ufw enable
ufw status verbose

# Fail2Ban — Proteção contra brute force SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban
fail2ban-client status sshd
```

## Instalação do Docker

```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Adicionar usuário deploy ao grupo docker
usermod -aG docker deploy

# Habilitar Docker no boot
systemctl enable docker

# Verificar instalação
docker --version
docker compose version
```

## Estrutura de Diretórios no Servidor

```bash
# Criar diretório da aplicação
mkdir -p /opt/wolfapp
chown deploy:deploy /opt/wolfapp

# Estrutura esperada
/opt/wolfapp/
  docker-compose.prod.yml
  .env.prod
  nginx/
    nginx.conf
  backups/
    scripts/
      backup.sh
```

## Instalação e Configuração Nginx

```bash
apt install -y nginx
systemctl enable nginx
```

## Template nginx.conf Wolf

```nginx
# /etc/nginx/sites-available/wolfapp.conf
upstream wolfapp_api {
    server 127.0.0.1:3000;
    keepalive 32;
}

# Redirect HTTP → HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name app.wolfapp.com api.wolfapp.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS — API
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name api.wolfapp.com;

    ssl_certificate     /etc/letsencrypt/live/api.wolfapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.wolfapp.com/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Tamanho máximo do body (ajustar para uploads)
    client_max_body_size 10M;

    # Timeouts
    proxy_connect_timeout 10s;
    proxy_send_timeout    60s;
    proxy_read_timeout    60s;

    location / {
        proxy_pass         http://wolfapp_api;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check sem log
    location /health {
        proxy_pass         http://wolfapp_api;
        access_log         off;
    }

    # Rate limiting básico
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=60r/m;
    limit_req zone=api_limit burst=20 nodelay;
}

# HTTPS — Frontend (Next.js / React)
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name app.wolfapp.com;

    ssl_certificate     /etc/letsencrypt/live/app.wolfapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.wolfapp.com/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Assets estáticos com cache agressivo
    location /_next/static/ {
        proxy_pass http://127.0.0.1:3001;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location / {
        proxy_pass         http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Ativar configuração
ln -s /etc/nginx/sites-available/wolfapp.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

## Plataformas Gerenciadas (Alternativa a VPS Própria)

| Plataforma  | Melhor para                          | Obs                               |
|-------------|--------------------------------------|-----------------------------------|
| Railway     | Apps Node/Python, projetos rápidos   | Escala automática, simples        |
| Render      | APIs e workers, free tier generoso   | Bom para staging                  |
| Fly.io      | Apps globais, multi-região           | Mais controle que Railway         |
| DigitalOcean App Platform | Apps sem gerenciar servidor | Mais caro que VPS própria |
| VPS própria | Controle total, custo menor em escala | Requer mais gestão               |

## Checklist de Setup de Servidor

- [ ] Sistema atualizado
- [ ] Usuário não-root criado e configurado
- [ ] Login root via SSH desabilitado
- [ ] Autenticação por chave SSH (sem senha)
- [ ] UFW configurado (apenas 22, 80, 443)
- [ ] Fail2ban ativo para SSH
- [ ] Docker instalado
- [ ] Nginx instalado e configurado
- [ ] SSL configurado (ver ssl.md)
- [ ] Diretório da aplicação criado com permissões corretas
- [ ] Monitoramento básico configurado (ver monitoring.md)
