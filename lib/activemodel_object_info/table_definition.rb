# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 重新扩展一些方法，用来方便在创建迁移文件的时候进行一些通用类的设定。
  # 从 @version 0.3.0 开始支持了自动创建的时间戳字段增加索引
  #
  # 核心作用与职责：
  # 在 ActiveRecord 数据库迁移（Migration）建表时，提供便捷的宏方法，
  # 一键生成通用的审计追踪字段（如操作人、操作时间）及软删除字段。
  #
  # @example 详细使用方法与示例
  #   class CreateUsers < ActiveRecord::Migration[6.1]
  #     def change
  #       create_table :users do |t|
  #         t.string :name
  #
  #         # 示例1: 生成指定的自定义操作字段
  #         t.operation_columns(:audit, with_operator: true, operator_prefix: 'my_', operator_suffix: '_user')
  #         # => 将会生成 my_audit_user (bigint) 和 audit_at (datetime) 字段
  #
  #         # 示例2: 生成常用的创建、更新、删除字段套装
  #         t.generate_operations
  #         # => 将会生成 created_by, created_at, updated_by, updated_at, deleted_by, deleted_at, 以及 deleted(integer)
  #       end
  #     end
  #   end
  #
  # 核心重要方法：
  # - {#operation_columns}：生成指定操作的审计字段（含前缀、后缀配置）。
  # - {#generate_operations}：批量生成创建、更新、删除相关的全套审计字段。
  #
  # @author shiner527 <shiner527@hotmail.com>
  #
  # [Changelog]
  #   [2026-07-28] 补充完整 YARD 文档、行内注释，清理尾随空格 (shiner527)
  #   [2021-04-20] 支持自动创建的时间戳字段增加索引 (@version 0.3.0) (shiner527)
  #   [2021-04-19] 创建基础模块，提供 operation_columns 与 generate_operations (shiner527)
  #
  module TableDefinition
    #
    # 生成操作相关的字段。包含操作人、操作时间等信息。
    #
    # @param [Symbol, String] fields 要生成的操作字段的名称。可以是字符串也可以是符号格式。相当于实际的前缀，会根据后续设置选项决定生成的字段内容。
    # @param [Hash] options 具体的设置选项，详见选项介绍。
    #
    # @option options [String] :operator_prefix 操作人字段前缀，默认为 +nil+ 。
    # @option options [String] :operator_suffix 操作人字段后缀，默认为 +'_by'+ 。
    # @option options [Boolean] :with_operator 是否生成用来记录对应操作的操作人信息，默认为 +true+ 。
    #  如果允许生成的话，会生成 <em><prefix></em><em><operation></em><em><suffix></em> 字段，默认为 <b>bigint</b> 类型。
    #
    #  * <em><prefix></em>: 前缀，由可选参数 <b>:operator_prefix</b> 提供，如果没有的话则使用默认值。
    #  * <em><operation></em>: 字段本体名称，即参数 <b>fields</b> 中给出的具体每个字段的名称本体。
    #  * <em><suffix></em>: 后缀，由可选参数 <b>:operator_suffix</b> 提供，如果没有的话则使用默认值。
    #
    # @option options [String] :timestamp_prefix 操作时间字段前缀，默认为 +nil+ 。
    # @option options [String] :timestamp_suffix 操作时间字段后缀，默认为 +'_at'+ 。
    # @option options [Boolean] :with_timestamp 是否生成用来记录对应操作的时间戳信息，默认为 +true+ 。
    #  如果允许生成的话，会生成 <em><prefix></em><em><operation></em><em><suffix></em> 字段，默认为 <b>datetime</b> 类型。
    #
    #  * <em><prefix></em>: 前缀，由可选参数 <b>:timestamp_prefix</b> 提供，如果没有的话则使用默认值。
    #  * <em><operation></em>: 字段本体名称，即参数 <b>fields</b> 中给出的具体每个字段的名称本体。
    #  * <em><suffix></em>: 后缀，由可选参数 <b>:timestamp_suffix</b> 提供，如果没有的话则使用默认值。
    #
    # @example
    #  operation_columns(:create, with_operator: true, operator_prefix: 'my_', operator_suffix: '_user')
    #  # => 会生成名为 'my_create_user' 的字段用来记录创建人信息。
    #
    def operation_columns(*fields, **options)
      # puts "operation_columns(#{fields}, #{options})"
      # 1. 提取并初始化各种设置选项，对于布尔值优先取用户配置，未配置则默认为 true
      with_operator = options[:with_operator].nil? ? true : options[:with_operator]
      with_timestamp = options[:with_timestamp].nil? ? true : options[:with_timestamp]
      operator_prefix = options[:operator_prefix]
      operator_suffix = options[:operator_suffix] || '_by'
      timestamp_prefix = options[:timestamp_prefix]
      timestamp_suffix = options[:timestamp_suffix] || '_at'

      # 2. 遍历每一个需要生成的操作标识符
      fields.each do |field|
        # 3. 动态拼接并生成操作人记录字段 (默认为 bigint 类型并添加索引)
        if with_operator
          operator_column_name = operator_prefix.to_s + field.to_s + operator_suffix.to_s
          column(operator_column_name, :bigint, index: true, comment: '操作人') if operator_column_name.present?
        end

        # 4. 动态拼接并生成操作时间戳字段 (默认为 datetime 类型并添加索引)
        if with_timestamp
          timestamp_column_name = timestamp_prefix.to_s + field.to_s + timestamp_suffix.to_s
          column(timestamp_column_name, :datetime, index: true, comment: '操作时间戳') if timestamp_column_name.present?
        end
      end
    end

    #
    # 生成对应操作的字段，包括操作人和操作时间戳，均使用默认设置。
    #
    # @param [Symbol, String] operations 对应的操作。默认会给出 +:created+ 、 +:updated+ 和 +:deleted+ 三个操作名。
    #  如果参数中的给出操作名含有 +:deleted+ 或者 +'deleted'+ 时，还会生成默认名称为 <b>deleted</b> 整形数字段，用来标识当前记录是否被删除。
    #  默认值为可用的记录标记值。由常量 {Constants::Base::TABLE_COLUMN_DELETE_DEFAULT} 设定。
    #
    def generate_operations(*operations)
      # puts "generate_operations(#{operations})"
      action_fields = operations

      # 1. 如果没有给出具体的动作名称，默认配置为创建、更新和删除这三个常规生命周期动作
      action_fields = %w[created updated deleted] if action_fields.empty?

      # 2. 遍历所有的动作名称以生成相应的字段
      action_fields.each do |operation|
        # 3. 特殊逻辑：当遇到 deleted 动作时，除了生成审计字段外，还需要额外部署一个整型的标记字段，用于承载软删除状态
        column(operation.to_s, :integer, default: 0, comment: '删除标记') if operation.to_sym == :deleted

        # 4. 复用 operation_columns 方法来生成对应的 xxx_by 操作人和 xxx_at 操作时间字段
        operation_columns(operation)
      end
    end
  end
end
