# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 重新扩展一些方法，用来方便在创建迁移文件的时候进行一些通用类的设定。
  # 从 @version 0.3.0 开始支持了自动创建的时间戳字段增加索引
  #
  # @author shiner527 <shiner527@hotmail.com>
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
      # 初始化设置选项
      with_operator = options[:with_operator].nil? ? true : options[:with_operator]
      with_timestamp = options[:with_timestamp].nil? ? true : options[:with_timestamp]
      operator_prefix = options[:operator_prefix]
      operator_suffix = options[:operator_suffix] || '_by'
      timestamp_prefix = options[:timestamp_prefix]
      timestamp_suffix = options[:timestamp_suffix] || '_at'
      # 依照每个字段进行设置
      fields.each do |field|
        # 如果要生成操作人信息
        if with_operator
          operator_column_name = operator_prefix.to_s + field.to_s + operator_suffix.to_s
          column(operator_column_name, :bigint, index: true, comment: '操作人') if operator_column_name.present?
        end
        # 如果要生成操作时间戳信息
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
      # 默认只有创建、更新和删除相关的字段
      action_fields = %w[created updated deleted] if action_fields.empty?
      action_fields.each do |operation|
        column(operation.to_s, :integer, default: 0, comment: '删除标记') if operation.to_sym == :deleted
        operation_columns(operation)
      end
    end
  end
end
