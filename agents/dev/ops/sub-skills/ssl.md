# ssl.md — Ops Sub-Skill: SSL/TLS & HTTPS
# Ativa quando: "ssl", "https", "certificado", "certbot"

## Certbot + Let's Encrypt

```bash
# Instalar Certbot
apt install -y certbot python3-certbot-nginx

# Emitir certificado (com Nginx já configurado para o domínio)
certbot --nginx -d api.wolfapp.com -d app.wolfapp.com \
  --email ops@wolfagency.com \
  --agree-tos \
  --non-interactive

# Verificar certificados emitidos
certbot certificates
```

**Resultado esperado:**
```
Found the following certs:
  Certificate Name: api.wolfapp.com
    Domains: api.wolfapp.com app.wolfapp.com
    Expiry Date: 2026-06-04 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/api.wolfapp.com/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/api.wolfapp.com/privkey.pem
```

## Renovação Automática

Let's Encrypt emite certificados com validade de 90 dias. O Certbot instala automaticamente um cron/systemd timer para renovação.

```bash
# Verificar se o timer está ativo
systemctl status certbot.timer

# Testar renovação sem de fato renovar (dry-run)
certbot renew --dry-run

# Forçar renovação imediata (quando necessário)
certbot renew --force-renewal
```

**Cron manual (fallback se o timer não estiver ativo):**
```bash
# Verificar se existe
crontab -l | grep certbot

# Adicionar se não existir
echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -
```

## Redirect HTTP → HTTPS (Nginx)

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name api.wolfapp.com app.wolfapp.com;

    # Necessário para renovação do Certbot
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
```

## Cloudflare SSL (Alternativa ao Let's Encrypt)

Quando o domínio já está atrás do Cloudflare, o processo é diferente:

**Opções de SSL no Cloudflare:**

| Modo          | Descrição                                          | Recomendado |
|---------------|----------------------------------------------------|-------------|
| Off           | Sem SSL                                            | Nunca       |
| Flexible      | Cloudflare → Origin sem criptografia               | Nunca       |
| Full          | Cloudflare → Origin com SSL (certificado qualquer) | Não         |
| Full (strict) | Cloudflare → Origin com certificado válido         | Sim         |

**Configuração Full (strict) com Certbot:**
```bash
# Emitir certificado normalmente com Certbot
# Configurar Nginx com SSL
# No Cloudflare: SSL/TLS → Overview → Full (strict)
```

**Certificado Origin do Cloudflare (alternativa ao Let's Encrypt):**
1. Cloudflare Dashboard → SSL/TLS → Origin Server → Create Certificate
2. Download do `certificate.pem` e `private-key.pem`
3. Salvar em `/etc/ssl/cloudflare/`
4. Configurar Nginx apontando para esses arquivos

```nginx
ssl_certificate     /etc/ssl/cloudflare/wolfapp.pem;
ssl_certificate_key /etc/ssl/cloudflare/wolfapp-key.pem;
```

**Vantagem:** certificado com validade de 15 anos, gerenciamento no Cloudflare.

## Configuração SSL Recomendada no Nginx

```nginx
# Incluir nas configurações HTTPS para segurança máxima
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
```

## Comandos de Diagnóstico

```bash
# Verificar certificado de um domínio remotamente
openssl s_client -connect api.wolfapp.com:443 -servername api.wolfapp.com 2>/dev/null | \
  openssl x509 -noout -dates

# Ver data de expiração
echo | openssl s_client -connect api.wolfapp.com:443 2>/dev/null | \
  openssl x509 -noout -enddate

# Verificar se certificado é válido e trusted
curl -v https://api.wolfapp.com/health 2>&1 | grep -E "(SSL|TLS|certificate)"

# Inspecionar certificado local
openssl x509 -in /etc/letsencrypt/live/api.wolfapp.com/fullchain.pem -noout -text

# Verificar cadeia de certificados
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
  /etc/letsencrypt/live/api.wolfapp.com/fullchain.pem

# Testar grade SSL (via CLI)
curl -s "https://api.ssllabs.com/api/v3/analyze?host=api.wolfapp.com&publish=off&startNew=on" | \
  python3 -m json.tool | grep grade

# Ver todos os domínios do certificado
openssl x509 -in /etc/letsencrypt/live/api.wolfapp.com/fullchain.pem -noout -ext subjectAltName
```

## Troubleshooting Comum

**Erro: `certbot: command not found`**
```bash
apt install -y certbot python3-certbot-nginx
```

**Erro: `Connection refused` na porta 80 durante emissão**
```bash
# Verificar se Nginx está rodando
systemctl status nginx
# Verificar se porta 80 está aberta no UFW
ufw status | grep 80
```

**Erro: `Certificate expired`**
```bash
certbot renew --force-renewal
systemctl reload nginx
```

**Erro: `too many requests` (rate limit Let's Encrypt)**
- Limite: 5 certificados por domínio a cada 7 dias
- Usar `--staging` para testes: `certbot --nginx --staging -d domain.com`
- Aguardar o período de cooldown

**Certificado emitido mas HTTPS não funciona**
```bash
nginx -t                  # verificar sintaxe
systemctl reload nginx    # recarregar configuração
```

## Checklist SSL

- [ ] Certificado emitido para todos os domínios/subdomínios necessários
- [ ] Redirect HTTP → HTTPS configurado no Nginx
- [ ] Renovação automática funcionando (`certbot renew --dry-run`)
- [ ] HSTS configurado (`Strict-Transport-Security`)
- [ ] TLS 1.2+ apenas (sem TLS 1.0/1.1)
- [ ] Alerta de expiração configurado (monitoramento, ver monitoring.md)
- [ ] Teste externo via SSL Labs passando com grade A
