# Quick Start Guide

The fastest way to get a new Rails app up and running with production deployment.

## 1. Create Your App (5 minutes)

```bash
rails new my_app \
  -d sqlite3 \
  -m https://raw.githubusercontent.com/davidrossdegroot/rails-starter/main/template.rb
```

**You'll be prompted for:**
- App name (e.g., `my_blog`)
- Docker Hub username
- Port number (e.g., `3000`, `3001`, `3002`)
- Primary domain (e.g., `myblog.com`)

## 2. Configure Secrets (2 minutes)

```bash
cd my_app
cp .env.example .env
```

Edit `.env` and add:
- `RAILS_MASTER_KEY` (from `config/master.key`)
- `KAMAL_REGISTRY_PASSWORD` (Docker Hub token)
- `GMAIL_USERNAME` (your Gmail address)
- `GOOGLE_APP_PASSWORD` (from https://myaccount.google.com/apppasswords - requires 2FA)

## 3. Local Development (1 minute)

```bash
bin/rails db:setup
bin/dev
```

Visit: http://localhost:3000

## 4. Domain Setup (10 minutes)

Add DNS records for your domain:

```
A     @     178.156.168.116
A     www   178.156.168.116
TXT   @     v=spf1 include:_spf.google.com ~all  (optional, for better deliverability)
```

> **Note**: No MX records needed unless you're receiving email on this domain.

Wait for DNS propagation (5-60 minutes).

## 5. First Deployment (15 minutes)

**On your server** (SSH: `ssh root@178.156.168.116`):

```bash
# Create storage directory
sudo mkdir -p /var/lib/YOUR_APP_NAME
sudo chown -R 1000:1000 /var/lib/YOUR_APP_NAME

# Copy nginx config
# (upload config/nginx-YOUR_APP_NAME.conf to server first)
sudo cp ~/nginx-YOUR_APP_NAME.conf /etc/nginx/sites-available/YOUR_APP_NAME
sudo ln -s /etc/nginx/sites-available/YOUR_APP_NAME /etc/nginx/sites-enabled/

# Generate SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

**From your local machine:**

```bash
cd ~/workspace/YOUR_APP_NAME
source .env
kamal deploy
```

## 6. Verify (1 minute)

```bash
# Check health
curl https://yourdomain.com/up

# View logs
kamal app logs -f
```

**Done!** Your app is live at https://yourdomain.com

---

## Daily Workflow

```bash
# Make changes
git add .
git commit -m "Your changes"

# Deploy
source .env && kamal deploy
```

## Common Commands

```bash
# View logs
kamal app logs -f

# Rails console
kamal console

# Rollback
kamal rollback

# Restart
kamal app restart
```

---

**For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)**
