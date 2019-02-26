require "multi_tenancy_database/version"
require 'thor'

require_relative 'multi_tenancy_database/version'
require_relative 'multi_tenancy_database/command'
require_relative 'multi_tenancy_database/generator'

module MultiTenancyDatabase
  class Error < StandardError; end
  def self.generator!(options)
    MultiTenancyDatabase::Generator.new(options).run
  end
end
