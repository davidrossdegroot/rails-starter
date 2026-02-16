# Rails Application Template
# Usage: rails new my_app -d sqlite3 -m https://raw.githubusercontent.com/YOU/rails-starter/main/template.rb

def source_paths
  [__dir__]
end

# Add standard gems
gem_group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "byebug", "~> 12.0"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "factory_bot_rails", "~> 6.5"
  gem "rspec-rails", "~> 8.0"
end

gem_group :development, :test do
  gem "dotenv-rails"
end

gem_group :development do
  gem "web-console"
end

gem_group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 6.0"
end

# Essential gems
gem "bcrypt", "~> 3.1.7"
gem "tailwindcss-rails", "~> 4.3"
gem "httparty"
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Deployment
gem "kamal", require: false
gem "thruster", require: false

# Error tracking
gem "sentry-ruby"
gem "sentry-rails"

# Analytics
gem "ahoy_matey"
gem "blazer"

# Lock rdoc to avoid warnings
gem "rdoc", "~> 7.0.3"

after_bundle do
  # Install RSpec
  generate "rspec:install"

  # Configure shoulda-matchers
  inject_into_file "spec/rails_helper.rb", after: "RSpec.configure do |config|\n" do
    <<-RUBY
  # Shoulda Matchers configuration
  config.include(Shoulda::Matchers::ActiveModel, type: :model)
  config.include(Shoulda::Matchers::ActiveRecord, type: :model)
    RUBY
  end

  append_to_file "spec/rails_helper.rb" do
    <<-RUBY

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
    RUBY
  end

  # Copy standard files
  directory "files", ".", force: true

  # Make hooks executable
  chmod ".kamal/hooks/pre-deploy", 0755

  # Prompt for app-specific configuration
  app_name = ask("What is your app name? (e.g., 'my_app')")
  docker_username = ask("What is your Docker Hub username?")
  app_port = ask("What port should this app use? (e.g., 3000, 3001, 3002)")
  primary_domain = ask("What is your primary domain? (e.g., example.com)")

  # Generate Kamal deploy.yml from template
  @app_name = app_name
  @docker_username = docker_username
  @app_port = app_port
  @primary_domain = primary_domain

  template "files/config/deploy.yml.tt", "config/deploy.yml"

  # Generate nginx config from template
  template "files/nginx/site.conf.tt", "config/nginx-#{app_name}.conf"

  # Create .env.example with app-specific values
  create_file ".env.example" do
    <<~ENV
      # Rails
      RAILS_MASTER_KEY=your_master_key_here

      # Database (not needed for sqlite, but useful for future)
      # DATABASE_URL=sqlite3:storage/production.sqlite3

      # Docker Registry
      KAMAL_REGISTRY_PASSWORD=your_docker_hub_token_here

      # Email (Gmail with App Password)
      # Create a Gmail account, enable 2FA, then generate an App Password
      GMAIL_USERNAME=your_gmail_address@gmail.com
      GOOGLE_APP_PASSWORD=your_16_char_app_password_here

      # Error Tracking (Sentry)
      SENTRY_DSN=your_sentry_dsn_here

      # Analytics Dashboard (Blazer)
      BLAZER_USERNAME=admin
      BLAZER_PASSWORD=change_this_secure_password

      # Add your app-specific environment variables below:
    ENV
  end

  # Configure Action Mailer for Gmail in all environments
  # Enable error reporting in development
  gsub_file "config/environments/development.rb",
            /config\.action_mailer\.raise_delivery_errors = false/,
            "config.action_mailer.raise_delivery_errors = true"

  inject_into_file "config/environments/development.rb", before: /^end\n/ do
    <<-RUBY

  # Gmail SMTP configuration for development
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.gmail.com",
    port: 587,
    domain: "#{primary_domain}",
    user_name: ENV["GMAIL_USERNAME"],
    password: ENV["GOOGLE_APP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
    RUBY
  end

  # Enable error reporting in production
  gsub_file "config/environments/production.rb",
            /# config\.action_mailer\.raise_delivery_errors = false/,
            "config.action_mailer.raise_delivery_errors = true"

  inject_into_file "config/environments/production.rb", before: /^end\n/ do
    <<-RUBY

  # Set host to be used by links generated in mailer templates
  config.action_mailer.default_url_options = { host: "#{primary_domain}", protocol: "https" }

  # Gmail SMTP configuration for production
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.gmail.com",
    port: 587,
    domain: "#{primary_domain}",
    user_name: ENV["GMAIL_USERNAME"],
    password: ENV["GOOGLE_APP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
    RUBY
  end

  # Update production.rb for sqlite
  gsub_file "config/environments/production.rb",
            /config\.active_storage\.service = :.*/,
            "config.active_storage.service = :local"

  # Configure solid_queue in puma
  inject_into_file "config/environments/production.rb", after: "config.eager_load = true\n" do
    <<-RUBY

  # Run Solid Queue in Puma process
  config.solid_queue_in_puma = ENV.fetch("SOLID_QUEUE_IN_PUMA", "true") == "true"
    RUBY
  end

  # Configure Sentry for error tracking
  create_file "config/initializers/sentry.rb" do
    <<~RUBY
      # Only initialize Sentry if DSN is configured
      if ENV['SENTRY_DSN'].present?
        Sentry.init do |config|
          config.dsn = ENV['SENTRY_DSN']
          config.breadcrumbs_logger = [:active_support_logger, :http_logger]

          # Set traces_sample_rate to 1.0 to capture 100%
          # of transactions for performance monitoring.
          # We recommend adjusting this value in production.
          config.traces_sample_rate = 0.1

          # Set profiles_sample_rate to profile 100%
          # of sampled transactions.
          # We recommend adjusting this value in production.
          config.profiles_sample_rate = 0.1

          # Only enable in production
          config.enabled_environments = %w[production]
          # Associate events with a specific deployment/revision
          app_revision = ENV['APP_REVISION'].presence
          config.release = app_revision if app_revision.present?
        end
      end
    RUBY
  end

  # Install Ahoy for analytics
  generate "ahoy:install"

  # Install Blazer for analytics dashboard
  generate "blazer:install"

  # Pin Ahoy.js via importmap (secure, no CDN dependencies)
  run "bin/importmap pin ahoy.js@0.4.2"

  # Add Ahoy JavaScript to application layout (with error handling)
  layout_file = "app/views/layouts/application.html.erb"
  if File.exist?(layout_file)
    # Try to inject after javascript_importmap_tags
    if File.read(layout_file).include?("javascript_importmap_tags")
      inject_into_file layout_file, after: "<%= javascript_importmap_tags %>\n" do
        <<-ERB
    <%= javascript_include_tag "ahoy", type: "module" %>
        ERB
      end
    else
      # Fallback: inject in head section
      inject_into_file layout_file, before: "</head>" do
        <<-ERB
    <%= javascript_include_tag "ahoy", type: "module" %>
        ERB
      end
    end
  else
    say "⚠️  Warning: Could not find #{layout_file}. Please manually add Ahoy tracking.", :yellow
    say "   Add this to your layout: <%= javascript_include_tag \"ahoy\", type: \"module\" %>", :yellow
  end

  # Configure Blazer with authentication
  create_file "config/initializers/blazer.rb" do
    <<~RUBY
      # Blazer authentication - uses HTTP Basic Auth by default
      # Override this if using Devise or other authentication system
      Blazer.authenticate = lambda do |request|
        if Rails.env.development?
          true # No auth required in development
        else
          # HTTP Basic Auth in production/staging
          authenticate_or_request_with_http_basic do |username, password|
            username == ENV["BLAZER_USERNAME"] &&
            password == ENV["BLAZER_PASSWORD"] &&
            ENV["BLAZER_USERNAME"].present? &&
            ENV["BLAZER_PASSWORD"].present?
          end
        end
      end
    RUBY
  end

  # Mount Blazer (authentication configured in initializer)
  inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
    <<-RUBY
  # Analytics dashboard (Blazer) - secured via HTTP Basic Auth
  mount Blazer::Engine, at: "blazer"

    RUBY
  end

  # Initial git commit
  git :init
  git add: "."
  git commit: "-m 'Initial commit from rails-starter template\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>'"

  say "\n" + "="*80
  say "🎉 Your Rails app is ready!"
  say "="*80
  say "\nNext steps:"
  say "  1. Review and update .env.example with your actual values"
  say "  2. Copy .env.example to .env and fill in secrets"
  say "  3. Set up Gmail for email:"
  say "     - Create/use Gmail account with 2FA enabled"
  say "     - Generate App Password: https://myaccount.google.com/apppasswords"
  say "     - Add GMAIL_USERNAME and GOOGLE_APP_PASSWORD to .env"
  say "  4. Run: bin/rails db:setup (creates database and runs migrations)"
  say "  5. Read DEPLOYMENT.md for comprehensive deployment instructions"
  say "  6. Check out README.md for recommended add-ons (Devise)"
  say "  7. Analytics dashboard at /blazer (HTTP Basic Auth in production)"
  say "  8. Your nginx config template is at: config/nginx-#{app_name}.conf"
  say "  9. Copy .kamal/secrets-example to .kamal/secrets for deployment"
  say " 10. Run: bin/dev"
  say "\n"
  say "To test email, generate a test mailer:"
  say "  rails g mailer Test test_email"
  say "  View preview at: http://localhost:3000/rails/mailers"
  say "\n"
end
