# Activemodel::Object::Info

[English](README.md) | [中文文档](README.zh-CN.md)

**Activemodel::Object::Info** 是一个用于扩展 `ActiveModel` 和 `ActiveRecord` 的 Ruby Gem。它为日常业务开发中常见的数据输出格式化、数据库迁移中的审计追踪字段生成、以及软删除（Soft Delete）功能提供了优雅且标准化的解决方案。

## 目录

- [核心特性](#核心特性)
- [适用场景](#适用场景)
- [安装指南](#安装指南)
- [详细使用方法](#详细使用方法)
  - [1. 模型数据格式化输出 (Base)](#1-模型数据格式化输出-base)
  - [2. 数据库迁移宏 (TableDefinition)](#2-数据库迁移宏-tabledefinition)
  - [3. 软删除机制 (DeletedOperation)](#3-软删除机制-deletedoperation)
- [开发与测试](#开发与测试)
- [开源协议](#开源协议)

## 核心特性

1. **模型数据格式化 (`Base`)**：安全、灵活地将 `ActiveRecord` 实例转换为 Hash（便于输出为 JSON）。支持字段白名单、黑名单、字段别名、自定义转换逻辑以及时间格式化。
2. **数据库迁移宏 (`TableDefinition`)**：在创建数据库表时，一键生成常见的审计字段（例如 `created_by`, `updated_by`, `deleted_by`）以及配套的时间戳。
3. **软删除机制 (`DeletedOperation`)**：基于整型标记字段的标准软删除实现，自动注入隐藏已删除数据的 `default_scope`，并在删除时强制记录操作人及时间。

## 适用场景

- **RESTful API 开发**：当你需要统一且高度可配置的方式，将 ActiveRecord 模型序列化为 JSON 响应并过滤掉敏感数据时。
- **企业级 / B2B 系统后台**：业务上对数据的审计追踪（Audit Trails）要求极其严格，必须精准记录每一条数据是谁在什么时候创建、修改和删除的。
- **数据留存要求高的系统**：严禁在数据库中执行硬删除（Destroy），要求所有的删除操作均采用软删除（Soft Delete）以备后续追溯。

## 安装指南

将以下代码添加到你项目中的 Gemfile 里：

```ruby
gem 'activemodel-object-info', '~> 0.4.0'
```

然后执行依赖安装：

```bash
$ bundle install
```

## 详细使用方法

### 1. 模型数据格式化输出 (Base)

`ActivemodelObjectInfo::Base` 模块为你的模型注入了 `instance_info` 方法。它能让你基于类中预定义的常量或运行时传入的参数，将实例对象输出为格式化的 Hash。

**在模型中配置：**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::Base

  # 定义默认的输出配置选项
  INSTANCE_INFO = {
    only: [:id, :name, :status, :created_at],
    attributes: [
      :id,
      { name: :name, as: :user_name }, # 使用 as 设定别名
      { name: :status, filter: ->(v) { v == 1 ? '活跃' : '停用' } }, # 使用 lambda 自定义转换逻辑
      { name: :created_at, format: :date }, # 格式化日期为 ('%Y-%m-%d')
      { name: :virtual_field, type: :abstract, filter: ->(*) { "#{id}-#{name}" } } # 根据其他字段合成的虚拟字段
    ]
  }.freeze
end
```

**实际调用：**

```ruby
user = User.first

# 不传参时，默认使用模型中的 INSTANCE_INFO 常量配置
user.instance_info 
# => { id: 1, user_name: "John", status: "活跃", created_at: "2026-07-28", virtual_field: "1-John" }

# 运行时覆盖配置（完美兼容 Ruby 2.x 的 Hash 传参和 Ruby 3.x 的关键字参数）
user.instance_info(only: [:id, :name])
# => { id: 1, name: "John" }
```

### 2. 数据库迁移宏 (TableDefinition)

`ActivemodelObjectInfo::TableDefinition` 模块对 ActiveRecord 的 Migration 进行了扩展，让你能够毫不费力地生成审计字段。

**在迁移文件中的使用：**

```ruby
class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :name
      
      # 1. 批量生成全套生命周期审计字段：
      # 将会自动生成: created_by, created_at, updated_by, updated_at, deleted(int), deleted_by, deleted_at
      t.generate_operations
      
      # 2. 或者生成指定的自定义审计字段：
      # 将会自动生成: audit_by (bigint), audit_at (datetime)
      t.operation_columns(:audit)
      
      # 3. 甚至高度自定义前后缀：
      # 将会自动生成: my_review_user (bigint), my_review_time (datetime)
      t.operation_columns(:review, operator_prefix: 'my_', operator_suffix: '_user', timestamp_suffix: '_time')
    end
  end
end
```

### 3. 软删除机制 (DeletedOperation)

`ActivemodelObjectInfo::DeletedOperation` 模块提供了一套开箱即用的软删除功能，并且与 `TableDefinition` 宏生成的底层字段完美契合。

**在模型中配置：**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::DeletedOperation
  
  # 可选：如果你的遗留数据库使用了其他命名习惯，可以覆盖以下常量
  # DELETED_FIELD = 'is_deleted'
  # DELETED_VALID_VALUE = false
  # DELETED_INVALID_VALUE = true
end
```

**实际调用：**

```ruby
# 1. 自动查询作用域：
# 引入该模块后，会自动注入 `default_scope` 隐藏已被删除的记录。
User.all # 实际执行 => SELECT * FROM users WHERE deleted = 0

# 2. 执行软删除：
user = User.find(1)

# 出于安全和审计规范，你【必须】提供执行删除操作的用户 ID (user_id)
user.soft_delete(user_id: current_user.id)
# 这一步将自动执行以下操作：
# - 将 `deleted` 标记设为 1
# - 将 `deleted_by` 设为 current_user.id
# - 将 `deleted_at` 设为当前时间 Time.now
# - 调用 `save` 保存到数据库

# 3. 软删除并同时刷新更新时间 (updated_at):
user.soft_delete(user_id: current_user.id, refresh_updated: true)

# 4. 强校验软删除 (底层调用 save!，失败时抛出异常):
user.soft_delete!(user_id: current_user.id)
```

## 开发与测试

克隆本仓库后，运行 `bin/setup` 安装开发依赖。

运行 RSpec 单元测试：
```bash
$ bundle exec rspec
```

运行 RuboCop 代码风格静态检查：
```bash
$ bundle exec rubocop
```

## 开源协议

本项目遵循 [MIT License](https://opensource.org/licenses/MIT) 开源协议。
