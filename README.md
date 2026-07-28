# Activemodel::Object::Info

[English](README.md) | [中文文档](README.zh-CN.md)

**Activemodel::Object::Info** is a Ruby Gem designed to extend `ActiveModel` and `ActiveRecord`. It provides an elegant and standardized way to handle common business requirements such as API data formatting, audit trails generation in database migrations, and soft-delete capabilities.

## Table of Contents

- [Features](#features)
- [Applicable Scenarios](#applicable-scenarios)
- [Installation](#installation)
- [Usage](#usage)
  - [1. Data Formatting (Base)](#1-data-formatting-base)
  - [2. Migration Macros (TableDefinition)](#2-migration-macros-tabledefinition)
  - [3. Soft Delete (DeletedOperation)](#3-soft-delete-deletedoperation)
- [Development & Testing](#development--testing)
- [License](#license)

## Features

1. **Model Data Formatting (`Base`)**: Safely and flexibly format `ActiveRecord` instances into Hashes (JSON ready) with whitelisting, blacklisting, aliasing, and custom formatting.
2. **Database Migration Macros (`TableDefinition`)**: One-click generation of audit fields (e.g., `created_by`, `updated_by`, `deleted_by`) and their corresponding timestamps.
3. **Soft Delete (`DeletedOperation`)**: Standardized soft-delete implementation using an integer flag, coupled with automatic `default_scope` injection and audit trail recording.

## Applicable Scenarios

- **RESTful API Development**: When you need a unified and configurable way to serialize ActiveRecord models into JSON responses, avoiding sensitive data leakage.
- **Enterprise / B2B Systems**: When strict data audit trails are required (tracking exactly *who* performed the creation, update, or deletion and *when*).
- **Data Retention Requirements**: Systems that prohibit hard deletion (destroy) and require records to be marked as deleted (Soft Delete) instead.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activemodel-object-info', '~> 0.4.1'
```

And then execute:

```bash
$ bundle install
```

## Usage

### 1. Data Formatting (Base)

The `ActivemodelObjectInfo::Base` module adds the `instance_info` method to your models. It allows you to output formatted hashes based on predefined or runtime configurations.

**Setup in Model:**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::Base

  # Define default output configuration
  INSTANCE_INFO = {
    only: [:id, :name, :status, :created_at],
    attributes: [
      :id,
      { name: :name, as: :user_name }, # Aliasing
      { name: :status, filter: ->(v) { v == 1 ? 'Active' : 'Inactive' } }, # Custom lambda filter
      { name: :created_at, format: :date }, # Date formatting ('%Y-%m-%d')
      { name: :virtual_field, type: :abstract, filter: ->(*) { "#{id}-#{name}" } } # Virtual field
    ]
  }.freeze

  # Define contextual output configuration (Must be named INSTANCE_INFO_{CONTEXT})
  INSTANCE_INFO_DETAIL = {
    only: [:id, :name, :email, :phone]
  }.freeze
end
```

**Usage:**

```ruby
user = User.first

# 1. Use the default INSTANCE_INFO constant
user.instance_info 
# => { id: 1, user_name: "John", status: "Active", created_at: "2026-07-28", virtual_field: "1-John" }

# 2. Contextual output: Pass `context` to automatically use the corresponding INSTANCE_INFO_{CONTEXT} constant
user.instance_info(context: :detail)
# => { id: 1, name: "John", email: "a@b.com", phone: "12345" }

# 3. Override at runtime (Supports Ruby 2.x Hash and Ruby 3.x Keyword Arguments)
user.instance_info(only: [:id, :name])
# => { id: 1, name: "John" }

# 4. Nested output for Associations (includes)
user.instance_info(
  only: [:id, :name],
  includes: {
    profile: { only: [:avatar_url, :bio] },     # Single instance (has_one / belongs_to)
    roles: { only: [:role_name] }               # Collection (has_many)
  }
)
# => { 
#      id: 1, name: "John", 
#      profile: { avatar_url: "...", bio: "..." }, 
#      roles: [{ role_name: "admin" }, { role_name: "editor" }] 
#    }
```

### 2. Migration Macros (TableDefinition)

The `ActivemodelObjectInfo::TableDefinition` module extends ActiveRecord's migration capabilities to generate audit fields effortlessly.

**Setup:**
This is usually loaded automatically, but you can explicitly extend it if needed in your initializers.

**Usage in Migrations:**

```ruby
class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :name
      
      # Generates full audit suite:
      # created_by, created_at, updated_by, updated_at, deleted(int), deleted_by, deleted_at
      t.generate_operations
      
      # Or generate specific custom audit fields:
      # Generates: audit_by (bigint), audit_at (datetime)
      t.operation_columns(:audit)
      
      # Generates: my_review_user (bigint), my_review_time (datetime)
      t.operation_columns(:review, operator_prefix: 'my_', operator_suffix: '_user', timestamp_suffix: '_time')
    end
  end
end
```

### 3. Soft Delete (DeletedOperation)

The `ActivemodelObjectInfo::DeletedOperation` module provides an out-of-the-box soft deletion feature that works perfectly with the fields generated by `TableDefinition`.

**Setup in Model:**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::DeletedOperation
  
  # Optional: Override default column names and values if your database uses different conventions
  # DELETED_FIELD = 'is_deleted'
  # DELETED_VALID_VALUE = false
  # DELETED_INVALID_VALUE = true
end
```

**Usage:**

```ruby
# 1. Automatic Scope: 
# The module automatically injects a `default_scope` to hide deleted records.
User.all # => SELECT * FROM users WHERE deleted = 0

# 2. Perform Soft Delete:
user = User.find(1)

# You MUST provide the `user_id` of the operator performing the deletion
user.soft_delete(user_id: current_user.id)
# This will:
# - Set `deleted` to 1
# - Set `deleted_by` to current_user.id
# - Set `deleted_at` to Time.now
# - Call `save`

# 3. Soft Delete and refresh updated_at:
user.soft_delete(user_id: current_user.id, refresh_updated: true)

# 4. Strict Soft Delete (raises exception on failure):
user.soft_delete!(user_id: current_user.id)

# 5. Restore soft-deleted record (Undelete):
# This resets the `deleted` flag to 0 and clears `deleted_by` and `deleted_at`
user.restore

# 6. Restore and refresh updated_at with user_id:
user.restore(user_id: current_user.id, refresh_updated: true)
```

## Development & Testing

After checking out the repo, run `bin/setup` to install dependencies.

To run tests:
```bash
$ bundle exec rspec
```

To run code style checks:
```bash
$ bundle exec rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
