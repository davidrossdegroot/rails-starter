# Rails Starter Template

A production-ready Rails 8 application template with opinionated defaults for rapid development and deployment.

## Features

### Tech Stack
- **Rails 8.1** with modern defaults
- **SQLite3** for all environments (dev/test/prod)
- **Tailwind CSS 4.3** for styling
- **Hotwire** (Turbo + Stimulus) for interactivity
- **Solid Queue/Cache/Cable** for background jobs, caching, and WebSockets

### Development Tools
- **RSpec** with FactoryBot, Capybara, and Shoulda Matchers
- **RuboCop Rails Omakase** for linting
- **Brakeman** for security scanning
- **bundler-audit** for gem vulnerability scanning
- **dotenv-rails** for environment variable management

### CI/CD
- **GitHub Actions** workflows for automated testing and deployment
- **Continuous Integration** runs security scans, linting, and tests on every PR
- **Continuous Deployment** automatically deploys to production on merge to main

### Deployment
- **Kamal 2** for containerized deployment
- **Docker** with optimized multi-stage builds
- **nginx** reverse proxy with SSL termination
- **MailerSend SMTP** for transactional email delivery
- Pre-configured for Hetzner VPS deployment

## Quick Start

### Create a New App

```bash
rails new my_app \
  -d sqlite3 \
  -m https://raw.githubusercontent.com/davidrossdegroot/rails-starter/main/template.rb
```

During setup, you'll be prompted for:
- **App name** (e.g., `my_blog`)
- **Docker Hub username**
- **Port number** (e.g., `3000`, `3001`, `3002` - each app needs a unique port)
- **Primary domain** (e.g., `myblog.com`)

### Post-Setup Steps

1. **Configure secrets:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Set up database:**
   ```bash
   bin/rails db:setup
   ```

3. **Start development server:**
   ```bash
   bin/dev
   ```

4. **Run tests:**
   ```bash
   rspec
   ```

5. **For deployment, see [DEPLOYMENT.md](DEPLOYMENT.md)** for comprehensive instructions.

## Recommended Add-ons

### Authentication with Devise

The template includes `bcrypt` for basic authentication, but for full-featured user authentication, we recommend **Devise**. It's easy to add after creating your app:

```bash
bundle add devise
rails generate devise:install
rails generate devise User
rails generate devise:views
rails db:migrate
```

Devise provides:
- Email/password authentication
- Password recovery
- Email confirmation
- Account locking
- Session management
- And more!

**Resources:**
- [Devise GitHub](https://github.com/heartcombo/devise)
- [Devise Documentation](https://github.com/heartcombo/devise#getting-started)

### Analytics with Google Analytics

Google Analytics is configured through a production-only GA4 tag in the application layout. Set `GOOGLE_ANALYTICS_ID` to your measurement ID, such as `G-XXXXXXXXXX`, before deploying.

**Already set up:**
- Layout tag only runs in production
- Tracking is disabled unless `GOOGLE_ANALYTICS_ID` is present
- Turbo page visits are tracked with `turbo:load`
- No analytics tables, migrations, or dashboard gems are added

**Track custom events in your app:**
```javascript
gtag("event", "sign_up", { method: "email" });
gtag("event", "purchase", { value: 99.99, currency: "USD" });
```

View traffic and events in your Google Analytics property.

## What Gets Configured

### Gems Added
- Authentication: `bcrypt`
- Styling: `tailwindcss-rails`
- HTTP client: `httparty`
- Background jobs: `solid_queue`
- Caching: `solid_cache`
- WebSockets: `solid_cable`
- Monitoring: `sentry-ruby`, `sentry-rails`
- Deployment: `kamal`, `thruster`
- Testing: `rspec-rails`, `factory_bot_rails`, `capybara`, `selenium-webdriver`, `shoulda-matchers`
- Code quality: `rubocop-rails-omakase`, `brakeman`, `bundler-audit`

### Files Copied
- `.rubocop.yml` - RuboCop configuration
- `.ruby-version` - Ruby 4.0.1
- `Dockerfile` - Optimized for production with SQLite3
- `config/deploy.yml` - Kamal deployment configuration
- `.kamal/hooks/pre-deploy` - Automatic container cleanup
- `config/nginx-{app_name}.conf` - nginx reverse proxy template
- `.env.example` - Environment variable template

### Email Configuration
- Configured MailerSend SMTP in development and production
- Uses `MAILERSEND_SMTP_USERNAME` and `MAILERSEND_SMTP_PASSWORD` from environment
- Uses `MAILERSEND_DOMAIN` for SMTP domain/HELO configuration
- Uses `MAILER_DEFAULT_FROM` for the default sender address
- Requires a verified MailerSend sending domain and SMTP credentials

### Database
- SQLite3 for all environments
- Production database stored in `/var/lib/{app_name}` on server
- Automatic migrations on deploy

## Architecture Decisions

### Why SQLite for Production?
- **Simplicity**: No separate database server to manage
- **Performance**: Fast for read-heavy workloads
- **Cost**: No database hosting costs
- **Reliability**: Perfect for low-to-medium traffic applications
- **Backup**: Simple file-based backups

For high-traffic or write-heavy apps, you can easily switch to PostgreSQL later.

### Why No Kamal-Proxy?
This template assumes deployment to a **shared server** with multiple applications. nginx is already handling SSL termination and routing for all apps, so kamal-proxy would conflict with the existing setup.

**Trade-off**: No zero-downtime deployments, but the pre-deploy hook minimizes downtime to ~30-60 seconds.

## Project Structure

```
my_app/
├── config/
│   ├── deploy.yml              # Kamal configuration (app-specific)
│   └── nginx-{app_name}.conf   # nginx template (copy to server)
├── .kamal/
│   └── hooks/
│       └── pre-deploy          # Auto-cleanup old containers
├── Dockerfile                   # Production container
├── .env.example                 # Environment variable template
├── .rubocop.yml                 # Linting rules
├── spec/                        # RSpec tests
└── CLAUDE.md                    # AI assistant context
```

## Environment Variables

Required variables (set in `.env`; secret values also go in `.kamal/secrets`):

```bash
RAILS_MASTER_KEY=xxx           # Generated by Rails
KAMAL_REGISTRY_PASSWORD=xxx    # Docker Hub token
MAILERSEND_DOMAIN=xxx          # MailerSend sending domain
MAILERSEND_SMTP_USERNAME=xxx   # MailerSend SMTP username
MAILERSEND_SMTP_PASSWORD=xxx   # MailerSend SMTP password
MAILER_DEFAULT_FROM="My App <noreply@example.com>"
SENTRY_DSN=xxx                 # Sentry DSN for error tracking and monitoring
GOOGLE_ANALYTICS_ID=xxx        # Google Analytics measurement ID
```

## CI/CD with GitHub Actions

This template includes two GitHub Actions workflows:

### Continuous Integration (`.github/workflows/ci.yml`)
Runs automatically on every pull request with parallel jobs:

1. **Security Scanning (Ruby)**: Runs Brakeman and bundler-audit to catch security vulnerabilities
2. **Security Scanning (JavaScript)**: Audits importmap dependencies
3. **Linting**: Runs RuboCop with intelligent caching for faster runs
4. **Testing**: Runs full RSpec suite with Capybara system tests, uploads screenshots on failure

### Continuous Deployment (`.github/workflows/deploy.yml`)
Automatically deploys to production when code is merged to main:

- Uses Kamal for zero-downtime deployments
- Builds and pushes Docker images
- Manages all secrets via GitHub Secrets

### Setting Up GitHub Actions

After creating your app from this template, configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

**Required Secrets:**
- `RAILS_MASTER_KEY` - Your Rails master key (from `config/master.key`)
- `KAMAL_REGISTRY_PASSWORD` - Docker Hub access token
- `KAMAL_REGISTRY_USERNAME` - Your Docker Hub username
- `SSH_PRIVATE_KEY` - SSH private key for server access
- `MAILERSEND_SMTP_USERNAME` - MailerSend SMTP username
- `MAILERSEND_SMTP_PASSWORD` - MailerSend SMTP password
- `SENTRY_DSN` - Sentry DSN for error tracking and monitoring
- `GOOGLE_ANALYTICS_ID` - Google Analytics measurement ID

Once secrets are configured, every PR will be automatically tested, and every merge to main will deploy to production!

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for step-by-step deployment instructions covering:
- Domain setup and DNS configuration
- SSL certificate generation
- nginx configuration
- Port allocation
- Initial deployment
- Ongoing deployments

## Contributing

This is a personal template, but feel free to fork and customize for your needs.

## License

MIT
