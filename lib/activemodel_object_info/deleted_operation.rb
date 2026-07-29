# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 用来进行和删除操作相关的数据库模型的功能模组。主要结合了使用 +:deleted+ 字段标识数据软删除的功能。
  #
  # 核心作用与职责：
  # 为 ActiveRecord 模型提供标准化的“软删除（Soft Delete）”功能。
  # 引入该模块后，会自动通过 `default_scope` 过滤掉已标记为删除的记录，
  # 并注入 `soft_delete` / `soft_delete!` 方法。在执行软删除时，会自动更新
  # 相关的审计字段（如 deleted_by, deleted_at, updated_by）。
  #
  # @example 详细使用方法与示例
  #   class User < ApplicationRecord
  #     include ActivemodelObjectInfo::DeletedOperation
  #
  #     # 可选：覆盖默认的配置常量
  #     DELETED_FIELD = 'is_deleted'
  #     DELETED_VALID_VALUE = false
  #     DELETED_INVALID_VALUE = true
  #   end
  #
  #   # 1. 默认查询过滤
  #   # 查询数据时会自动应用 default_scope: WHERE is_deleted = false
  #   User.all
  #
  #   # 2. 软删除记录
  #   # 软删除一条记录（必须要传入 user_id 用于审计）
  #   user = User.find(1)
  #   user.soft_delete(user_id: current_user.id, refresh_updated: true)
  #   # 此时 user 的 is_deleted 变为 true，同时 deleted_at, deleted_by, updated_by 都会被更新
  #
  #   # 3. 恢复软删除的数据
  #   # 因为已经被软删除的数据会被 default_scope 过滤，所以需要使用 unscoped 查出
  #   deleted_user = User.unscoped.find(1)
  #   # 执行恢复操作，同样可以传入 user_id 记录是谁执行的恢复，并选择是否刷新 updated_at
  #   deleted_user.restore(user_id: current_user.id, refresh_updated: true)
  #   # 此时 user 的 is_deleted 变为 false，同时 deleted_at 和 deleted_by 会被清空，updated_by 会被更新
  #
  # 核心重要方法：
  # - {#soft_delete}：执行软删除并调用 save 更新数据。
  # - {#soft_delete!}：执行软删除并调用 save! 更新数据（抛出异常）。
  # - {#restore}：恢复已软删除的数据。
  # - {#restore!}：强制恢复已软删除的数据（抛出异常）。
  # - {#delete_block}：底层通用的删除字段赋值逻辑块。
  #
  # @author shiner527 <shiner527@hotmail.com>
  #
  # [Changelog]
  #   [2026-07-28] 新增 restore 与 restore! 方法以支持软删除数据恢复 (shiner527)
  #   [2026-07-28] 补充完整 YARD 文档、行内注释，清理尾随空格 (shiner527)
  #   [2021-04-19] 创建基础模块，提供软删除与作用域注入功能 (shiner527)
  #
  module DeletedOperation
    extend ::ActiveSupport::Concern

    # 当被 include 关键字引入后的处理
    included do |_|
      # 1. 提取常量配置：如果宿主类定义了覆盖常量，则使用宿主类的，否则使用默认值
      deleted_field = const_defined?(:DELETED_FIELD) ? DELETED_FIELD : 'deleted'
      deleted_value_valid = const_defined?(:DELETED_VALID_VALUE) ? DELETED_VALID_VALUE : 0
      deleted_value_invalid = const_defined?(:DELETED_INVALID_VALUE) ? DELETED_INVALID_VALUE : 1

      # 2. 注入 default_scope 默认查询作用域：如果模型拥有删除标记字段，则默认查询自动排除被标记的数据
      default_scope do
        current_model = try(:name).to_s.safe_constantize
        where(deleted_field.to_sym => deleted_value_valid) if current_model.has_attribute?(deleted_field)
      end

      # 3. 定义底层的删除逻辑块 (给实例对象的内存属性赋值)
      define_method(:delete_block) do |**options|
        # 处理可选项参数：默认不刷新 updated_at 字段
        options[:refresh_updated] = options[:refresh_updated].nil? ? false : options[:refresh_updated]

        # 必须要传递操作的用户ID信息，强制审计规范
        raise ArgumentError, 'Must give user id!' if options[:user_id].blank?

        # 提取字段名配置
        updated_by_field = (options[:updated_by_field] || 'updated_by').to_sym
        deleted_by_field = (options[:deleted_by_field] || 'deleted_by').to_sym
        deleted_at_field = (options[:deleted_at_field] || 'deleted_at').to_sym

        # 核心：设置删除状态为已失效标记值
        __send__("#{deleted_field}=", deleted_value_invalid)

        # 审计：如果模型存在对应的审计字段，则设置删除人、删除时间，以及根据配置选择性地设置更新人
        __send__("#{deleted_by_field}=", options[:user_id]) if respond_to?(deleted_by_field)
        __send__("#{deleted_at_field}=", Time.now.localtime) if respond_to?(deleted_at_field)
        __send__("#{updated_by_field}=", options[:user_id]) if respond_to?(updated_by_field) && options[:refresh_updated]
      end

      # 4. 暴露的常规软删除方法 (使用 save 存储，返回 boolean)
      define_method(:soft_delete) do |**options|
        opts = options.deep_symbolize_keys
        # 安全防范：如果没有定义删除标记字段则直接返回，不执行任何操作
        return unless respond_to?(deleted_field)

        delete_block(**opts)

        # 调用 ActiveRecord 内置方法持久化，根据 refresh_updated 参数决定是否让系统自动更新 updated_at
        save(touch: opts[:refresh_updated])
      end

      # 5. 暴露的强校验软删除方法 (使用 save! 存储，失败抛出异常)
      define_method(:soft_delete!) do |**options|
        opts = options.deep_symbolize_keys
        return unless respond_to?(deleted_field)

        delete_block(**opts)

        save!(touch: opts[:refresh_updated])
      end

      # 6. 底层的恢复逻辑块 (给实例对象的内存属性赋值，清除删除标记)
      define_method(:restore_block) do |**options|
        options[:refresh_updated] = options[:refresh_updated].nil? ? false : options[:refresh_updated]

        updated_by_field = (options[:updated_by_field] || 'updated_by').to_sym
        deleted_by_field = (options[:deleted_by_field] || 'deleted_by').to_sym
        deleted_at_field = (options[:deleted_at_field] || 'deleted_at').to_sym

        # 核心：恢复状态为有效标记值
        __send__("#{deleted_field}=", deleted_value_valid)

        # 审计：清除删除人、删除时间，根据配置选择性地设置恢复操作的更新人
        __send__("#{deleted_by_field}=", nil) if respond_to?(deleted_by_field)
        __send__("#{deleted_at_field}=", nil) if respond_to?(deleted_at_field)
        __send__("#{updated_by_field}=", options[:user_id]) if respond_to?(updated_by_field) && options[:user_id].present? && options[:refresh_updated]
      end

      # 7. 暴露的常规软删除恢复方法
      define_method(:restore) do |**options|
        opts = options.deep_symbolize_keys
        return unless respond_to?(deleted_field)

        restore_block(**opts)

        save(touch: opts[:refresh_updated])
      end

      # 8. 暴露的强校验软删除恢复方法
      define_method(:restore!) do |**options|
        opts = options.deep_symbolize_keys
        return unless respond_to?(deleted_field)

        restore_block(**opts)

        save!(touch: opts[:refresh_updated])
      end
    end
  end
end
