# Application Context for Claude AI

## Application Overview
[Describe your application here - what it does, who it's for, and its core purpose]

## Key Features
[List the main features and functionality]

## Technical Stack

### Backend: Ruby on Rails 8.1
- **Database**: SQLite3 for all environments
- **Authentication**: Custom authentication with bcrypt (if implemented)
- **Background Jobs**: Solid Queue for async processing
- **Caching**: Solid Cache for performance
- **WebSockets**: Solid Cable for real-time features
- **Testing**: RSpec with FactoryBot, Capybara for system tests
- **Security**: Brakeman for vulnerability scanning
- **Linting**: RuboCop Rails Omakase

### Frontend: Modern Rails Stack
- **Stimulus.js** controllers for interactive features
- **Turbo** for SPA-like navigation
- **Tailwind CSS** for styling (v4.3)
- **Importmap** for JavaScript module management

### External Services (if applicable)
[List any external APIs or services you integrate with]

### Data Models
[Document your key models and their relationships]

```
Example:
User
├── email, password_digest
├── has_many :posts

Post
├── title, body
├── belongs_to :user
```

### Key Routes
[List your main routes and what they do]

- Root: `pages#home` - Landing page
- [Add your routes here]

### Development Commands
- Start: `bin/dev` (starts Rails server and Tailwind CSS)
- Tests: `rspec`
- Console: `bin/rails console`
- Linting: `rubocop`

### Deployment
- **Docker** containerization
- **Kamal 2** for deployment automation (without built-in proxy)
- **nginx** as reverse proxy on production server
  - Handles SSL termination via Let's Encrypt certificates
  - Proxies requests to Rails app on assigned port
  - Shared server setup supporting multiple applications

#### Deployment Architecture
The application runs on a Hetzner VPS (178.156.168.116) alongside other applications. Key architectural details:

- **Port binding**: Rails app runs in Docker container and exposes port 3000 to the host on a unique port
- **Reverse proxy**: nginx receives all HTTPS traffic and proxies to `127.0.0.1:YOUR_PORT`
- **SSL certificates**: Managed by certbot (Let's Encrypt) and configured in nginx
- **Kamal configuration**: `config/deploy.yml` publishes assigned port with `proxy: false`

#### Why No Kamal-Proxy?
**kamal-proxy is disabled** (`proxy: false` in deploy.yml) because this is a **shared server** hosting multiple applications. nginx is already managing SSL termination and routing for all apps on the server. Using kamal-proxy would conflict with the existing nginx setup.

**Trade-off**: Without kamal-proxy, zero-downtime rolling deployments are not possible when binding to a specific port. There is brief downtime (~30-60 seconds) during deployments.

#### Deployment Process & Port Conflict Prevention
**Problem**: When deploying without kamal-proxy, the new container cannot bind to the assigned port if the old container is still running, causing "port already allocated" errors.

**Solution**: Pre-deploy hook (`.kamal/hooks/pre-deploy`) automatically:
1. Stops all old containers gracefully (30s timeout)
2. Verifies port is freed before continuing
3. Allows new container to start successfully

This eliminates the need to manually SSH into the server to stop containers.

To deploy: `kamal deploy` from project root

### Environment Variables Needed
- `RAILS_MASTER_KEY` - for encrypted credentials
- `KAMAL_REGISTRY_PASSWORD` - for deployment (Docker Hub token)
- `RESEND_EMAIL_API_KEY` - for transactional email delivery via Resend

[Add any additional environment variables your app needs]

### Email Configuration
- **Development**: Uses Resend SMTP (smtp.resend.com:587)
- **Production**: Uses Resend SMTP with verified domain
- **From address**: `noreply@YOUR_DOMAIN.com`

### Testing Strategy
- RSpec for unit/integration tests
- System tests with Capybara for full browser testing
- Factory Bot for test data generation

## Development Guidelines

### Code Style
- Follow RuboCop Rails Omakase conventions
- Run `rubocop` before committing
- Security scans with `brakeman`

### Git Workflow
[Describe your preferred git workflow]

### Database Migrations
[Document any special migration considerations]

### Background Jobs
[Document how background jobs are used in your app]

## TODOs / Technical Debt
[Track known issues and planned improvements]

## Notes for AI Assistants
- Always prefer editing existing files over creating new ones
- Run RuboCop after making changes: `rubocop -A`
- Run tests after significant changes: `rspec`
- Check for security issues: `brakeman`
- When adding new features, update this CLAUDE.md file
- Use Solid Queue for background processing, not async adapter
- SQLite is used in production - be mindful of concurrency limitations

## Useful Commands Reference

```bash
# Development
bin/dev                          # Start server with Tailwind watch
bin/rails console                # Rails console
bin/rails routes                 # View all routes

# Testing
rspec                            # Run all tests
rspec spec/models                # Run model tests
rspec spec/system                # Run system tests

# Code Quality
rubocop                          # Check Ruby style
rubocop -A                       # Auto-correct offenses
brakeman                         # Security scan

# Database
bin/rails db:migrate             # Run migrations
bin/rails db:rollback            # Rollback last migration
bin/rails db:seed                # Seed database
bin/rails db:reset               # Drop, create, migrate, seed

# Deployment
kamal deploy                     # Deploy to production
kamal rollback                   # Rollback deployment
kamal app logs -f                # Tail production logs
kamal console                    # Production Rails console
```

---

**Keep this file updated as your application evolves!**
