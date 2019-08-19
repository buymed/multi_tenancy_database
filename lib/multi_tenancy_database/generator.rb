require 'multi_tenancy_database'
require 'fileutils'   

module MultiTenancyDatabase
  class Generator
    def initialize(args)
      @template_path = "#{__dir__}/templates"
      @options = args
      @current_dir = get_current_dir
    end

    def run
      puts 'Starting generate database'
      puts '1. Create config connect to new database'
      copy_config
      puts '2. Created migration'
      copy_migrate
      puts '3. Created generation command'
      copy_libs_generators
      puts '4. Created tasks'
      copy_libs_tasks
      puts '5. Created module model'
      copy_model
      puts 'Done generate database'
      show_summary
    end

    private
    def show_summary
      puts %Q(Please fill user/password connect to database database_#{database_name}.
To create new model for database #{database_name}:
  rails g #{database_name}_model <model-name> field:type[, ....]
  Ex: rails g #{database_name}_model user name:string address:string
To create new migration for model #{database_name}:
  rails g #{database_name}_migration <migration-name> field:type[, ....]
  Ex: rails g #{database_name}_migration AddPhoneFieldToUser phone:string
To run migration
  rails g #{database_name}:db:migrate
      )  
    end

    def copy_config
      dir = "#{@current_dir}/config/"
      FileUtils.mkdir_p("#{dir}databases")

      puts "\t.Created database_#{database_name}.yml"
      f = File.open("#{dir}databases/database_#{database_name}.yml", 'w')
      f.puts database_config_template
      f.close

      f = File.open("#{dir}initializers/db_#{database_name}.rb", 'w')
      f.puts constant_template
      f.close
    end

    def constant_template
      %Q(config=YAML::load(ERB.new(File.read(Rails.root.join('config','databases/database_#{database_name}.yml'))).result)
#{database_name.upcase}_DB = config[Rails.env]        
      )
    end

    def database_config_template
      %Q(default: &default
  adapter: #{adapter}
  encoding: unicode
  # For details on connection pooling, see Rails configuration guide
  # http://guides.rubyonrails.org/configuring.html#database-pooling
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  username: <%= ENV['DEV_DATABASE_#{database_name.upcase}_USERNAME'] %>
  password: <%= ENV['DEV_DATABASE_#{database_name.upcase}_PASSWORD'] %>
  database: #{database_name}_dev

test:
  <<: *default
  username: <%= ENV['TEST_DATABASE_#{database_name.upcase}_USERNAME'] %>
  password: <%= ENV['TEST_DATABASE_#{database_name.upcase}_PASSWORD'] %>
  database: #{database_name}_test

production:
  <<: *default
  username: <%= ENV['PROD_DATABASE_#{database_name.upcase}_USERNAME'] %>
  password: <%= ENV['PROD_DATABASE_#{database_name.upcase}_PASSWORD'] %>
  database: #{database_name}_prod
      )      
    end

    def copy_model
      dir = "#{@current_dir}/app/models/#{database_name}_db"
      FileUtils.mkdir_p("#{dir}")
      f = File.open("#{dir}/base.rb", 'w')
      f.puts base_template_content
      f.close  
    end

    def base_template_content
      %Q(module #{camelize}Db
  class Base < ActiveRecord::Base
    self.abstract_class = true
    establish_connection #{database_name.upcase}_DB
  end
end
      )      
    end

    def copy_libs_tasks
      dir = "#{@current_dir}/lib/"
      FileUtils.mkdir_p("#{dir}/tasks")

      f = File.open("#{dir}/tasks/db_#{database_name}.rake", 'w')
      f.puts rake_template_content
      f.close      
    end

    def copy_libs_generators
      dir = "#{@current_dir}/lib/"
      FileUtils.mkdir_p("#{dir}/generators/templates")
      
      puts "\t.Created template #{database_name}_db_model.rb"
      f = File.open("#{dir}/generators/templates/#{database_name}_db_model.rb.tt", 'w')
      f.puts model_template_content
      f.close
      
      puts "\t.Created template #{database_name}_migration_generator.rb"
      f = File.open("#{dir}/generators/#{database_name}_migration_generator.rb", 'w')
      f.puts migration_generation
      f.close
      
      puts "\t.Created template #{database_name}_model_generator.rb"
      f = File.open("#{dir}/generators/#{database_name}_model_generator.rb", 'w')
      f.puts model_generation
      f.close

    end

    def rake_template_content
      %Q(task spec: ['#{database_name}:db:test:prepare']

namespace :#{database_name} do
  namespace :db do |ns|
    %i(drop create setup migrate rollback seed version).each do |task_name|
      task task_name do
        Rake::Task["db:\#{task_name}"].invoke
      end
    end

    namespace :schema do
      %i(load dump).each do |task_name|
        task task_name do
          Rake::Task["db:schema:\#{task_name}"].invoke
        end
      end
    end

    namespace :structure do
      %i(load dump).each do |task_name|
        task task_name do
          ENV['SCHEMA'] = 'db/#{database_name}s/structure.sql'
          Rake::Task["db:structure:\#{task_name}"].invoke
        end
      end
    end

    namespace :test do
      task :prepare do
        Rake::Task['db:test:prepare'].invoke
      end
    end

    # append and prepend proper tasks to all the tasks defined here above
    ns.tasks.each do |task|
      task.enhance ['#{database_name}:set_custom_config'] do
        Rake::Task['#{database_name}:revert_to_original_config'].invoke
      end
    end
  end

  task :set_custom_config do
    # save current vars
    @original_config = {
      env_schema: ENV['SCHEMA'],
      config: Rails.application.config.dup
    }

    # set config variables for custom database
    ENV['SCHEMA'] = 'db/#{database_name}s/schema.rb'
    Rails.application.config.paths['db'] = ['db/#{database_name}s']
    Rails.application.config.paths['db/migrate'] = ['db/#{database_name}s/migrate']
    # If you are using Rails 5 or higher change `paths['db/seeds']` to `paths['db/seeds.rb']`
    Rails.application.config.paths['db/seeds'] = ['db/#{database_name}s/seeds.rb']
    Rails.application.config.paths['config/database'] = ['config/databases/database_#{database_name}.yml']
  end

  task :revert_to_original_config do
    # reset config variables to original values
    ENV['SCHEMA'] = @original_config[:env_schema]
    Rails.application.config = @original_config[:config]
  end
end
      )      
    end

    def model_generation
      %Q(require 'rails/generators/active_record/model/model_generator'

class #{camelize}ModelGenerator < ActiveRecord::Generators::ModelGenerator
  ActiveRecord::Generators::ModelGenerator
    .instance_method(:create_model_file)

  migration_file = File.dirname(
    ActiveRecord::Generators::ModelGenerator
      .instance_method(:create_migration_file)
      .source_location.first
  )

  source_root File.join(migration_file, "templates")

  def create_migration_file
    return unless options[:migration] && options[:parent].nil?
    attributes.each { |a| a.attr_options.delete(:index) if a.reference? && !a.has_index? } if options[:indexes] == false
    migration_template "../../migration/templates/create_table_migration.rb", File.join('db/#{database_name}s/migrate', "create_\#{table_name}.rb")
  end

  def create_model_file
    template Rails.root.join('lib', 'generators', "templates", "#{database_name}_db_model.rb"), File.join("app/models", class_path, "\#{file_name}.rb")
  end
end
      )
    end

    def migration_generation
      %Q(require 'rails/generators/active_record/migration/migration_generator'

class #{camelize}MigrationGenerator < ActiveRecord::Generators::MigrationGenerator
  migration_file = File.dirname(
    ActiveRecord::Generators::MigrationGenerator
      .instance_method(:create_migration_file)
      .source_location.first
  )

  source_root File.join(migration_file, "templates")

  def create_migration_file
    set_local_assigns!
    validate_file_name!
    migration_template @migration_template, "db/#{database_name}s/migrate/\#{file_name}.rb"
  end
end
      )
    end

    def model_template_content
      %Q(<% module_namespacing do -%>
class <%= class_name %> < #{camelize}Db::Base
<% attributes.select(&:reference?).each do |attribute| -%>
  belongs_to :<%= attribute.name %><%= ', polymorphic: true' if attribute.polymorphic? %><%= ', required: true' if attribute.required? %>
<% end -%>
<% attributes.select(&:token?).each do |attribute| -%>
  has_secure_token<% if attribute.name != "token" %> :<%= attribute.name %><% end %>
<% end -%>
<% if attributes.any?(&:password_digest?) -%>
  has_secure_password
<% end -%>
end
<% end -%>          
      )
    end

    def copy_migrate
      dir = "#{@current_dir}/db/#{database_name}s"
      FileUtils.mkdir_p("#{dir}/migrate")

      f = File.open("#{dir}/schema.rb", 'w')
      f.close

      f = File.open("#{dir}/seed.rb", 'w')
      f.close
    end

    def camelize
      database_name.split('_').map {|w| w.capitalize}.join
    end

    def database_name
      @options[:name].downcase
    end

    def adapter
      @options[:adapter].downcase
    end

    def get_current_dir
      if defined?(Rails)
        return Rails.root
      end

      if defined?(Bundler)
        return Bundler.root
      end
      
      Dir.pwd
    end
  end
end
