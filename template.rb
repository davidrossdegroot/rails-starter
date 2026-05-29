# Rails Application Template
# Usage: rails new my_app -d sqlite3 -m https://raw.githubusercontent.com/YOU/rails-starter/main/template.rb

def source_paths
  [__dir__]
end

# Add standard gems
gem_group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
  gem "factory_bot_rails", "~> 6.5"
  gem "rspec-rails", "~> 8.0"
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

# Error tracking and monitoring
gem "sentry-ruby"
gem "sentry-rails"

# Analytics are handled by Google Analytics via the application layout.

# Lock rdoc to avoid warnings
gem "rdoc", "~> 7.0.3"

after_bundle do
  # Install RSpec
  generate "rspec:install"

  # Create binstubs for CI tools
  run "bundle binstubs brakeman --force"
  run "bundle binstubs bundler-audit --force"
  run "bundle binstubs rubocop --force"

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
  app_display_name = app_name.tr("_-", " ").split.map(&:capitalize).join(" ")
  mailer_default_from = "#{app_display_name} <noreply@#{primary_domain}>"

  # Generate Kamal deploy.yml from template
  @app_name = app_name
  @docker_username = docker_username
  @app_port = app_port
  @primary_domain = primary_domain
  @app_display_name = app_display_name
  @mailer_default_from = mailer_default_from

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

      # Email (MailerSend SMTP)
      MAILERSEND_DOMAIN=#{primary_domain}
      MAILERSEND_SMTP_USERNAME=your_mailersend_smtp_username
      MAILERSEND_SMTP_PASSWORD=your_mailersend_smtp_password
      MAILER_DEFAULT_FROM=#{mailer_default_from.inspect}

      # Monitoring (Sentry)
      SENTRY_DSN=your_sentry_dsn_here

      # Analytics (Google Analytics)
      GOOGLE_ANALYTICS_ID=G-XXXXXXXXXX

      # Add your app-specific environment variables below:
    ENV
  end

  # Configure Action Mailer for MailerSend in all environments
  # Enable error reporting in development
  gsub_file "config/environments/development.rb",
            /config\.action_mailer\.raise_delivery_errors = false/,
            "config.action_mailer.raise_delivery_errors = true"

  inject_into_file "config/environments/development.rb", before: /^end\n/ do
    <<-RUBY

  # Set host to be used by links generated in mailer templates
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # MailerSend SMTP configuration for development
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.mailersend.net",
    port: 587,
    domain: ENV.fetch("MAILERSEND_DOMAIN", "#{primary_domain}"),
    user_name: ENV["MAILERSEND_SMTP_USERNAME"],
    password: ENV["MAILERSEND_SMTP_PASSWORD"],
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

  # MailerSend SMTP configuration for production
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.mailersend.net",
    port: 587,
    domain: ENV.fetch("MAILERSEND_DOMAIN", "#{primary_domain}"),
    user_name: ENV["MAILERSEND_SMTP_USERNAME"],
    password: ENV["MAILERSEND_SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
    RUBY
  end

  # Configure default sender for all mailers
  mailer_file = "app/mailers/application_mailer.rb"
  if File.exist?(mailer_file)
    gsub_file mailer_file,
              /default from: .*/,
              "  default from: ENV.fetch(\"MAILER_DEFAULT_FROM\", #{mailer_default_from.inspect})"
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

  # Configure Sentry for error tracking and monitoring
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

  # Add Google Analytics to application layout
  layout_file = "app/views/layouts/application.html.erb"
  google_analytics_snippet = <<-ERB
    <% if Rails.env.production? && ENV["GOOGLE_ANALYTICS_ID"].present? %>
      <!-- Google tag (gtag.js) -->
      <script async src="https://www.googletagmanager.com/gtag/js?id=<%= ENV["GOOGLE_ANALYTICS_ID"] %>"></script>
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag("js", new Date());
        gtag("config", "<%= ENV["GOOGLE_ANALYTICS_ID"] %>", { send_page_view: false });

        document.addEventListener("turbo:load", function() {
          gtag("event", "page_view", {
            page_title: document.title,
            page_location: window.location.href,
            page_path: window.location.pathname + window.location.search
          });
        });
      </script>
    <% end %>

  ERB

  if File.exist?(layout_file)
    if File.read(layout_file).include?("csp_meta_tag")
      inject_into_file layout_file, after: "<%= csp_meta_tag %>\n\n" do
        google_analytics_snippet
      end
    else
      inject_into_file layout_file, before: "</head>" do
        google_analytics_snippet
      end
    end
  else
    say "Warning: Could not find #{layout_file}. Please manually add Google Analytics tracking.", :yellow
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
  say "  3. Set up MailerSend SMTP for email:"
  say "     - Verify your sending domain in MailerSend"
  say "     - Create SMTP credentials"
  say "     - Add MAILERSEND_SMTP_USERNAME and MAILERSEND_SMTP_PASSWORD to .env"
  say "  4. Run: bin/rails db:setup (creates database and runs migrations)"
  say "  5. Read DEPLOYMENT.md for comprehensive deployment instructions"
  say "  6. Check out README.md for recommended add-ons (Devise)"
  say "  7. Add GOOGLE_ANALYTICS_ID to .env for production analytics"
  say "  8. Your nginx config template is at: config/nginx-#{app_name}.conf"
  say "  9. Copy .kamal/secrets-example to .kamal/secrets for deployment"
  say " 10. Run: bin/dev"
  say "\n"
  say "To test email, generate a test mailer:"
  say "  rails g mailer Test test_email"
  say "  View preview at: http://localhost:3000/rails/mailers"
  say "\n"
end
