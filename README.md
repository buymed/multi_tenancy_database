[![Gem Version](https://badge.fury.io/rb/multi_tenancy_database.svg)](https://badge.fury.io/rb/multi_tenancy_database)

# MultiTenancyDatabase

Allowing multiple databases to connect to the same project and still use ActiveRecord to perform operations on the models

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'multi_tenancy_database'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install multi_tenancy_database

## Usage

In this example, we’ll have a separate database for our e-commerce school that we’ll call school.

### Add new database

multi_tenancy_database -n school -a postgresql

### Create Database

rails school:db:create

### Create new model

rails g school_model user first_name:string last_name:string

### Add more field to model user

rails g school_migration AddPhoneFieldToUser phone:string

### Migrate

rails school:db:migrate