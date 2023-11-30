# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 用来进行和删除操作相关的数据库模型的功能模组。主要结合了使用 +:deleted+ 字段标识数据软删除的功能。
  #
  # @author shiner527 <shiner527@hotmail.com>
  #
  module DeletedOperation
    extend ::ActiveSupport::Concern

    # 当被 include 关键字引入后的处理
    included do |_|
      # 定义好默认的删除查询语句
      deleted_field = const_defined?(:DELETED_FIELD) ? DELETED_FIELD : 'deleted'
      deleted_value_valid = const_defined?(:DELETED_VALID_VALUE) ? DELETED_VALID_VALUE : 0
      deleted_value_invalid = const_defined?(:DELETED_INVALID_VALUE) ? DELETED_INVALID_VALUE : 1
      # 如果定义了删除标记字段则默认搜索自动排除该内容
      default_scope do
        _current_model = try(:name).to_s.safe_constantize
        where(deleted_field.to_sym => deleted_value_valid) if _current_model.has_attribute?(deleted_field)
      end

      # 通用的删除过程
      define_method(:delete_block) do |**options|
        # 处理可选项参数
        options[:refresh_updated] = options[:refresh_updated].nil? ? false : options[:refresh_updated]

        # 必须要传递操作的用户ID信息
        raise ArgumentError, 'Must give user id!' if options[:user_id].blank?

        # 获取更新人字段，删除人字段
        updated_by_field = (options[:updated_by_field] || 'updated_by').to_sym
        deleted_by_field = (options[:deleted_by_field] || 'deleted_by').to_sym
        deleted_at_field = (options[:deleted_at_field] || 'deleted_at').to_sym
        # 设置删除状态为已失效
        __send__("#{deleted_field}=", deleted_value_invalid)
        # 设置删除人、删除时间和更新人
        __send__("#{deleted_by_field}=", options[:user_id]) if respond_to?(deleted_by_field)
        __send__("#{deleted_at_field}=", Time.now.localtime) if respond_to?(deleted_at_field)
        __send__("#{updated_by_field}=", options[:user_id]) if respond_to?(updated_by_field) && options[:refresh_updated]
      end

      # 定义删除方法，但是不覆盖 ActiveRecord 的同名方法。
      define_method(:soft_delete) do |**options|
        opts = options.deep_symbolize_keys
        # 如果没有定义删除标记字段则不执行
        return unless respond_to?(deleted_field)
        delete_block(**opts)
        # 根据设置决定是否刷更新时间
        save(touch: opts[:refresh_updated])
      end

      # 定义删除方法，区别为最终调用 save! 方法更新数据，所以遇到异常会抛出异常
      define_method(:soft_delete!) do |**options|
        opts = options.deep_symbolize_keys
        return unless respond_to?(deleted_field)
        delete_block(**opts)
        # 根据设置决定是否刷更新时间
        save!(touch: opts[:refresh_updated])
      end
    end
  end
end
