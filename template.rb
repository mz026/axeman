@after_bundles = []
def after_bundle &block
  @after_bundles << block
end
@recipes = []
def current_path
  File.dirname(__FILE__)
end

# local settings
create_file "config/local_settings.yml", "# puts your localsettings here"
template File.join(current_path, 'templates', 'initializers', 'local_settings.rb.erb'),
  "config/initializers/local_settings.rb"

# gems
gem 'mysql2'
gem 'factory_girl_rails'
gem 'execjs'
gem 'therubyracer'

# rspec and spork setting
gem_group :test do 
  gem 'rspec-rails'
  gem 'webrat'
  gem 'spork'

  after_bundle do 
    generate 'rspec:install'
    run "bundle exec spork --bootstrap"
    inject_spork_config_snippet
    append_to_file ".rspec", "--drb" 
  end
end

def inject_spork_config_snippet
  inject_into_file "spec/spec_helper.rb", :after => "Spork.prefork do\n" do
    script_path = File.join(current_path, 'templates', 'spec_helper_for_spork.rb')
    spec_helper_for_spork = File.read script_path
  end
end


def create_cap_recipes
  template File.join(current_path, 'templates', 'deploy.rb.erb'), "config/deploy.rb"
  template File.join(current_path, 'templates', 'deploy', 'stage.rb.erb'),
    "config/deploy/development.rb", { :stage => 'development' }
  template File.join(current_path, 'templates', 'deploy', 'stage.rb.erb'),
    "config/deploy/production.rb", { :stage => 'production' }
end
if yes?("would you like to install Capistrano?")
  @recipes << "capistrano"
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'rvm-capistrano'

  create_cap_recipes
  append_to_file ".gitignore", "config/local_settings.yml\n"
  append_to_file ".gitignore", "config/database.yml\n"

  after_bundle do
    if @recipes.include? "delayed_job"
      append_delayed_job_cap_recipe
    end
  end
end

def append_delayed_job_cap_recipe
  inject_into_file "config/deploy.rb", 
    :after => "require \"capistrano/ext/multistage\"\n" do
      <<-RUBY
require "delayed/recipes"

      RUBY
  end

  append_to_file "config/deploy.rb", <<-RUBY
after "deploy:stop",    "delayed_job:stop"
after "deploy:start",   "delayed_job:start"
after "deploy:restart", "delayed_job:restart"
  RUBY
end

if yes?("would you like to install delayed_job?")
  @recipes << "delayed_job"
  gem 'delayed_job'
  gem 'delayed_job_active_record'
  gem 'daemons'

  after_bundle do
    generate "delayed_job:active_record"
    rake "db:migrate"
  end
end


after_bundle do
  git :init
  git :ignore => "*.swp\n"
  git :add => "."
  git :commit  => "-m 'init import'"
end

run 'bundle install'
@after_bundles.each do |block|
  block.call
end
