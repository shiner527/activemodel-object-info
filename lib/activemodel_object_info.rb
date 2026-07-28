# frozen_string_literal: true

require 'activemodel_object_info/version'
require 'active_support/all'
require 'activemodel_object_info/base'
require 'activemodel_object_info/table_definition'
require 'activemodel_object_info/deleted_operation'

#
# 扩展模组主入口。
#
# 核心作用与职责：
# 这是 activemodel-object-info Gem 的主命名空间和入口文件。
# 它负责统一加载所有相关的依赖库（ActiveSupport）和内部子模块（Base, TableDefinition, DeletedOperation）。
#
# @example 详细使用方法
#   require 'activemodel_object_info'
#
# 包含的核心模块：
# - {ActivemodelObjectInfo::Base}：提供模型对象信息格式化输出能力。
# - {ActivemodelObjectInfo::TableDefinition}：提供数据库迁移时自动生成审计字段的能力。
# - {ActivemodelObjectInfo::DeletedOperation}：提供记录软删除及其作用域管理的能力。
#
# @author shiner527 <shiner527@hotmail.com>
#
# [Changelog]
#   [2026-07-28] 补充完整 YARD 文档 (shiner527)
#   [2021-04-19] 创建基础模块结构及入口文件 (shiner527)
#
module ActivemodelObjectInfo
end
