# Deployment Guide

Comprehensive guide for deploying your Rails application to a Hetzner VPS with nginx, SSL, and Kamal.

## Prerequisites

- **Local machine**: Rails app created from this template
- **Hetzner VPS**: Ubuntu server at `178.156.168.116` (already set up)
- **Docker Hub account**: For hosting container images
- **Domain name**: Registered and ready to configure
- **Resend account**: For email delivery

---

## Part 1: Domain and DNS Setup

### 1.1 Register Your Domain

Register your domain with any registrar (Namecheap, GoDaddy, Cloudflare, etc.).

### 1.2 Configure DNS Records

Add the following DNS records in your domain registrar's control panel:

**A Records** (point to Hetzner server):
```
Type    Name    Value              TTL
A       @       178.156.168.116    Auto
A       www     178.156.168.116    Auto
```

**MX Records** (for Resend email):
```
Type    Name    Value                     Priority    TTL
MX      @       feedback-smtp.eu.resend.com    10        Auto
```

**TXT Record** (for SPF - email authentication):
```
Type    Name    Value                                      TTL
TXT     @       v=spf1 include:resend.com ~all             Auto
```

### 1.3 Verify DNS Propagation

Wait 5-60 minutes for DNS propagation, then verify:

```bash
# Check A record
dig yourdomain.com +short
# Should return: 178.156.168.116

# Check MX record
dig yourdomain.com MX +short
# Should return: 10 feedback-smtp.eu.resend.com
```

---

## Part 2: Resend Email Setup

### 2.1 Add Domain to Resend

1. Log in to [Resend Dashboard](https://resend.com/domains)
2. Click "Add Domain"
3. Enter your domain (e.g., `yourdomain.com`)
4. Follow verification instructions (add DNS TXT record)

### 2.2 Get API Key

1. Go to [API Keys](https://resend.com/api-keys)
2. Create new API key
3. Copy the key (starts with `re_`)
4. Save it for later use

### 2.3 Verify Domain

After adding DNS records, click "Verify" in Resend dashboard. Status should change to "Verified" (may take up to 24 hours).

---

## Part 3: Port Allocation Strategy

Since multiple apps run on the same server, each needs a unique port.

### 3.1 Port Assignment Convention

```
3000 - psalm-learner (existing app)
3001 - Your first new app
3002 - Your second new app
3003 - Your third new app
...
```

### 3.2 Check Available Ports

SSH into the server and check what's in use:

```bash
ssh root@178.156.168.116
docker ps --format '{{.Names}}\t{{.Ports}}' | grep 127.0.0.1
```

**Pick the next available port number** for your new app.

---

## Part 4: Server Setup (One-Time per App)

### 4.1 Create Storage Directory

SSH into the server and create a volume directory for your app's database:

```bash
ssh root@178.156.168.116
sudo mkdir -p /var/lib/YOUR_APP_NAME
sudo chown -R 1000:1000 /var/lib/YOUR_APP_NAME
```

This directory will store your SQLite database and Active Storage files.

### 4.2 Install nginx (if not already installed)

```bash
# Check if nginx is installed
which nginx

# If not installed:
sudo apt update
sudo apt install -y nginx

# Start and enable nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 4.3 Configure Firewall

Ensure ports 80 (HTTP) and 443 (HTTPS) are open:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

---

## Part 5: SSL Certificate Setup

### 5.1 Install Certbot

```bash
ssh root@178.156.168.116

# Install certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### 5.2 Generate SSL Certificate

**Important**: Run this AFTER configuring nginx (next section), or use standalone mode:

```bash
# Option 1: Standalone mode (run BEFORE nginx config)
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Option 2: nginx mode (run AFTER nginx config)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Follow prompts:
- Enter email address
- Agree to Terms of Service
- Choose whether to redirect HTTP to HTTPS (recommended: yes)

### 5.3 Verify Certificate

```bash
sudo certbot certificates
```

Certificates are stored at:
- `/etc/letsencrypt/live/yourdomain.com/fullchain.pem`
- `/etc/letsencrypt/live/yourdomain.com/privkey.pem`

### 5.4 Set Up Auto-Renewal

Certbot automatically configures renewal. Test it:

```bash
sudo certbot renew --dry-run
```

---

## Part 6: nginx Configuration

### 6.1 Copy nginx Config to Server

From your local machine, copy the generated nginx config:

```bash
scp config/nginx-YOUR_APP_NAME.conf root@178.156.168.116:/etc/nginx/sites-available/YOUR_APP_NAME
```

### 6.2 Enable the Site

SSH into server:

```bash
ssh root@178.156.168.116

# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/YOUR_APP_NAME /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
```

### 6.3 Verify nginx is Running

```bash
sudo systemctl status nginx
```

---

## Part 7: Local Environment Setup

### 7.1 Create `.env` File

```bash
cd ~/workspace/YOUR_APP_NAME
cp .env.example .env
```

### 7.2 Edit `.env` with Real Values

```bash
# Rails
RAILS_MASTER_KEY=your_actual_master_key_from_config_master_key

# Docker Registry
KAMAL_REGISTRY_PASSWORD=your_docker_hub_access_token

# Email
RESEND_EMAIL_API_KEY=re_your_actual_resend_key
```

### 7.3 Create `.kamal/secrets`

Kamal reads secrets from a file. Create it:

```bash
mkdir -p .kamal
cat > .kamal/secrets << 'EOF'
RAILS_MASTER_KEY=$RAILS_MASTER_KEY
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
RESEND_EMAIL_API_KEY=$RESEND_EMAIL_API_KEY
EOF
```

**Important**: Add `.kamal/secrets` to `.gitignore`:

```bash
echo ".kamal/secrets" >> .gitignore
```

### 7.4 Get Docker Hub Access Token

1. Go to [Docker Hub](https://hub.docker.com/)
2. Settings → Security → New Access Token
3. Copy token and add to `.env`

---

## Part 8: First Deployment

### 8.1 Verify Kamal Configuration

```bash
cat config/deploy.yml
```

Ensure:
- Service name matches your app
- Port number is correct and unique
- Docker username is correct
- Server IP is `178.156.168.116`

### 8.2 Install Kamal (if not already)

```bash
gem install kamal
```

Or if using bundler:

```bash
bundle exec kamal version
```

### 8.3 Deploy!

```bash
# Source environment variables
source .env

# Deploy the application
kamal deploy
```

This will:
1. Build Docker image locally
2. Push image to Docker Hub
3. SSH into server
4. Run pre-deploy hook (stop old containers)
5. Pull new image
6. Start new container on assigned port
7. Run database migrations

**Expected duration**: 5-10 minutes for first deploy.

### 8.4 Verify Deployment

```bash
# Check app is running
kamal app logs

# Check container status
kamal app details

# Visit your domain
curl https://yourdomain.com/up
# Should return: OK
```

---

## Part 9: Ongoing Deployments

### 9.1 Regular Deploy

After making changes:

```bash
git add .
git commit -m "Your changes"

# Deploy
source .env && kamal deploy
```

### 9.2 Rollback

If something goes wrong:

```bash
kamal rollback
```

### 9.3 Useful Kamal Commands

```bash
# View logs
kamal app logs -f

# SSH into container
kamal app exec -i bash

# Rails console
kamal console

# Run migrations
kamal app exec "bin/rails db:migrate"

# Restart app
kamal app restart

# Check app details
kamal app details

# Remove old images
kamal prune all
```

---

## Part 10: Database Backups

Since we're using SQLite, backups are simple file copies.

### 10.1 Manual Backup

```bash
ssh root@178.156.168.116
cd /var/lib/YOUR_APP_NAME
sudo tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz production.sqlite3
```

### 10.2 Automated Backups (Cron)

Create backup script on server:

```bash
ssh root@178.156.168.116
sudo nano /root/backup-YOUR_APP_NAME.sh
```

Add:

```bash
#!/bin/bash
BACKUP_DIR="/root/backups/YOUR_APP_NAME"
APP_DATA="/var/lib/YOUR_APP_NAME"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR
cd $APP_DATA
tar -czf $BACKUP_DIR/backup-$DATE.tar.gz production.sqlite3 storage/

# Keep only last 7 days of backups
find $BACKUP_DIR -name "backup-*.tar.gz" -mtime +7 -delete
```

Make executable:

```bash
chmod +x /root/backup-YOUR_APP_NAME.sh
```

Add to cron (daily at 2 AM):

```bash
crontab -e

# Add this line:
0 2 * * * /root/backup-YOUR_APP_NAME.sh
```

---

## Part 11: Monitoring and Logs

### 11.1 Application Logs

```bash
# Real-time logs
kamal app logs -f

# Last 100 lines
kamal app logs --tail 100
```

### 11.2 nginx Logs

```bash
ssh root@178.156.168.116

# Access logs
sudo tail -f /var/log/nginx/YOUR_APP_NAME_access.log

# Error logs
sudo tail -f /var/log/nginx/YOUR_APP_NAME_error.log
```

### 11.3 Health Check

Your app has a `/up` health endpoint:

```bash
curl https://yourdomain.com/up
# Should return: OK (200 status)
```

---

## Part 12: Troubleshooting

### Issue: Port Already Allocated

**Symptom**: Deploy fails with "port already allocated" error.

**Solution**: The pre-deploy hook should handle this, but if it persists:

```bash
ssh root@178.156.168.116
docker ps | grep YOUR_APP_NAME
docker stop <container_id>
```

Then redeploy.

### Issue: nginx 502 Bad Gateway

**Symptom**: Website shows "502 Bad Gateway" error.

**Cause**: App container not running or port mismatch.

**Solution**:

```bash
# Check if container is running
kamal app details

# Check nginx is proxying to correct port
sudo cat /etc/nginx/sites-enabled/YOUR_APP_NAME | grep proxy_pass

# Check app logs
kamal app logs
```

### Issue: SSL Certificate Fails

**Symptom**: Certbot fails to generate certificate.

**Solution**:

1. Ensure DNS is propagated: `dig yourdomain.com +short`
2. Ensure port 80 is open: `sudo ufw status`
3. Temporarily stop nginx: `sudo systemctl stop nginx`
4. Use standalone mode: `sudo certbot certonly --standalone -d yourdomain.com`
5. Restart nginx: `sudo systemctl start nginx`

### Issue: Email Not Sending

**Symptom**: Emails not being delivered.

**Solution**:

1. Check Resend API key is set: `kamal app exec "printenv RESEND_EMAIL_API_KEY"`
2. Verify domain in Resend dashboard
3. Check app logs: `kamal app logs | grep -i mail`
4. Test in Rails console:
   ```ruby
   kamal console
   ActionMailer::Base.smtp_settings
   ```

### Issue: Database Locked

**Symptom**: "Database is locked" errors.

**Cause**: SQLite doesn't handle high concurrency well.

**Solution**:

1. Short-term: Restart app: `kamal app restart`
2. Long-term: Consider PostgreSQL if traffic increases

---

## Part 13: Security Checklist

Before going live:

- [ ] SSL certificate installed and auto-renewing
- [ ] Firewall configured (UFW or equivalent)
- [ ] Database backups automated
- [ ] `RAILS_MASTER_KEY` kept secret (not in git)
- [ ] Strong passwords for server access
- [ ] SSH key-based authentication enabled
- [ ] Disable root login over SSH (optional but recommended)
- [ ] Keep server updated: `sudo apt update && sudo apt upgrade`

---

## Part 14: Production Optimization

### 14.1 Enable Force SSL

In `config/environments/production.rb`:

```ruby
config.force_ssl = true
```

### 14.2 Configure Action Cable (WebSockets)

If using WebSockets, ensure nginx config supports them (already included in template).

### 14.3 Add Monitoring

Consider adding:
- **AppSignal**: Application monitoring
- **Uptime Robot**: Uptime monitoring
- **Papertrail**: Log aggregation

---

## Quick Reference

### Essential Commands

```bash
# Deploy
source .env && kamal deploy

# Rollback
kamal rollback

# View logs
kamal app logs -f

# Console
kamal console

# SSH into container
kamal app exec -i bash

# Restart
kamal app restart

# Database console
kamal dbc

# Check status
kamal app details
```

### Server File Locations

```
/var/lib/YOUR_APP_NAME/         # Database & storage
/etc/nginx/sites-available/     # nginx configs
/etc/letsencrypt/live/          # SSL certificates
/var/log/nginx/                 # nginx logs
```

### Port Mapping

```
Your app listens on:         3000 (inside container)
Kamal maps to:               127.0.0.1:YOUR_PORT (on host)
nginx proxies from:          443 (public HTTPS)
```

---

## Need Help?

- **Kamal docs**: https://kamal-deploy.org/
- **Rails guides**: https://guides.rubyonrails.org/
- **nginx docs**: https://nginx.org/en/docs/
- **Resend docs**: https://resend.com/docs
- **Let's Encrypt**: https://letsencrypt.org/docs/

---

**You're all set!** 🚀

Your Rails app should now be running in production with SSL, email delivery, and automated deployments. Deploy often and iterate quickly!
