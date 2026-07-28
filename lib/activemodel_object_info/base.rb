# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 通用的设置操作项相关的模型方法和处理。
  #
  # 核心作用与职责：
  # 提供模型实例数据格式化输出能力。主要用于将 ActiveRecord 或 ActiveModel 的实例安全、灵活地转换为 Hash，
  # 方便后续转化为 JSON 等格式输出给前端，支持字段过滤、重命名、自定义处理及日期格式化。
  #
  # @example 详细使用方法与示例
  #   class User
  #     include ActivemodelObjectInfo::Base
  #     attr_accessor :id, :name, :created_at
  #
  #     INSTANCE_INFO = {
  #       only: [:id, :name, :created_at],
  #       attributes: [
  #         :id,
  #         { name: :name, as: :user_name },
  #         { name: :created_at, format: :date }
  #       ]
  #     }.freeze
  #   end
  #
  #   user = User.new(id: 1, name: "test", created_at: Time.now)
  #   user.instance_info # => { id: 1, user_name: "test", created_at: "2026-07-28" }
  #
  # 核心重要方法：
  # - {#instance_info}：核心输出方法，返回处理后的散列。
  #
  # @author shiner527 <shiner527@hotmail.com>
  #
  # [Changelog]
  #   [2026-07-28] 支持关联对象嵌套输出 (includes) 与场景化输出配置 (context) (shiner527)
  #   [2026-07-28] 补充完整 YARD 文档及核心注释，重构 instance_info 签名以兼容 Ruby 3.x 关键字参数 (shiner527)
  #   [2021-04-19] 创建基础模块，提供 instance_info 数据格式化输出功能 (shiner527)
  #
  module Base
    # ===== 常量定义 =====

    # 满格式
    DATETIME_FULL = '%Y-%m-%d %H:%M:%S'
    # 截止到分
    DATETIME_MIN = '%Y-%m-%d %H:%M'
    # 仅日期
    DATETIME_DATE = '%Y-%m-%d'
    # 仅年月
    DATETIME_MONTH = '%Y-%m'
    # 仅年份
    DATETIME_YEAR = '%Y'

    # ===== 方法定义 =====

    #
    # 对象信息输出。主要返回给前端一个可用的散列（会被转化为JSON格式）格式的信息并传递给前端。
    #
    # @param [Hash] options_hash 设置选项（传统位置参数 Hash），如果传入将被与 keyword_options 合并
    # @param [Hash] keyword_options 设置选项（Ruby 3 关键字参数）
    # @option keyword_options [Symbol, String] :context 场景上下文名称。如果提供，将优先读取 "INSTANCE_INFO_#{context.upcase}" 常量。
    # @option keyword_options [Array<Symbol, Hash>] :attributes 具体每一项输出的设置数组。每个元素既可以是标识符实例也可以是一个散列实例。
    #  如果是标识符实例，则表示输出该属性。如果是一个散列实例，则按照散列中的设定值去生成对应的内容。
    # @option keyword_options [Array<Symbol>] :only 给出具体可以用来输出的字段属性名数组。
    # @option keyword_options [Array<Symbol>] :except 给出需要被排除输出的字段属性名数组。
    # @option keyword_options [String, Symbol] :datetime_format 全局的时间格式设置。
    # @option keyword_options [Hash] :includes 需要嵌套输出的关联对象配置（如 { profile: { only: [:avatar] } }）。
    #
    # @return [Hash] 返回的处理过的该对象的信息散列。
    #
    def instance_info(options_hash = nil, **keyword_options)
      # 合并传统参数与关键字参数，完美兼容 Ruby 2.x 的 Hash 传参和 Ruby 3.x 的 **kwargs 传参
      options = (options_hash || {}).merge(keyword_options)

      # 尝试获取当前类上配置的常量作为默认选项
      # 优先级：传入的参数 options > 场景常量 INSTANCE_INFO_#{CONTEXT} > 默认常量 INSTANCE_INFO
      if options.blank? || (options.keys.map(&:to_sym) == [:context] && options[:context].present?)
        context_name = options[:context].to_s.upcase

        # 尝试寻找带场景的常量
        context_constant_name = "#{self.class}::INSTANCE_INFO_#{context_name}"
        options = context_constant_name.safe_constantize if context_name.present?

        # 如果带场景的常量不存在，或者没传场景，降级寻找默认常量
        options ||= "#{self.class}::INSTANCE_INFO".safe_constantize || {}
      end

      # 将 options 的 key 转为 symbol，避免传入字符串 key 导致匹配不到
      options = options.deep_symbolize_keys

      result = {}

      # 1. 整理包含字段和排除字段
      only_attributes = (options[:only] || []).map(&:to_sym)

      # 默认排除逻辑：如果不特意指定，系统会默认排除 deleted 等敏感字段，防止软删除数据泄漏
      default_deleted_column = ::Constants::Base::TABLE_COLUMN_DELETE_COLUMN rescue 'deleted'
      default_except_attrs = [
        default_deleted_column,
        "#{default_deleted_column}_by",
        "#{default_deleted_column}_at",
      ]
      except_attributes = (options[:except] || default_except_attrs).map(&:to_sym)

      # 2. 从当前类所有属性中计算出最终要输出的属性名集合
      attribute_configs = options[:attributes] || []
      output_attributes = attribute_names.map(&:to_sym)
      output_attributes &= only_attributes if only_attributes.present?
      output_attributes -= except_attributes

      # 3. 遍历并处理属性配置（attribute_configs）
      # 这里保证了要引入的类中含有 attributes 方法，且为 Hash 类型

      # 补丁：如果传入了 only_attributes，但是 options[:attributes] 是空（即调用方没传），
      # 我们需要将 only_attributes 中的字段视为基础配置，以确保只包含这几个字段的正常输出
      attribute_configs = only_attributes.map { |attr| { name: attr } } if attribute_configs.empty? && only_attributes.present?

      attribute_configs.each do |attr_config|
        # 根据配置项的类型（Symbol/String 或 Hash）提取字段名称和具体配置
        if [::String, ::Symbol].any? { |attr_class| attr_config.is_a?(attr_class) }
          attribute_name = attr_config.to_sym
          current_attr_config = {}
        elsif attr_config.is_a?(::Hash)
          current_attr_config = attr_config.deep_symbolize_keys
          attribute_name = current_attr_config[:name]
        else
          # 如果配置格式非法则直接跳过
          next
        end

        # 确定实际取值的属性名，支持通过 as 别名取值
        raw_name = current_attr_config[:as].present? ? current_attr_config[:as].to_sym : attribute_name
        filter = current_attr_config[:filter]

        # 取出对象中的实际值
        k = raw_name
        # 特殊处理 abstract 类型：当类型为抽象类时，由于可能没有对应的真实属性方法，直接赋值为 nil，后续依赖 filter 来生成实际值
        v = current_attr_config[:type] == :abstract ? nil : __send__(k)

        # 跳过条件：既不在最终输出名单中，也不是显式声明的 abstract/method 虚拟字段
        next unless output_attributes.include?(k) || %i[abstract method].include?(current_attr_config[:type])

        # 4. 根据类型或 filter 对值进行格式化转换
        if filter.present?
          # 如果配置了 filter，通过 Proc、Symbol(调用同名方法) 或 直接常量 的形式进行过滤转换
          result[attribute_name] = case filter
                                   when ::Proc
                                     instance_exec(v, &filter)
                                   when ::Symbol
                                     __send__(filter)
                                   else
                                     filter
                                   end
        elsif [::Date, ::Time, ::DateTime].any? { |time_class| v.is_a?(time_class) }
          # 对时间类型的字段进行格式化，优先级：字段级自定义 format > 全局 datetime_format > 默认全格式
          attribute_format = current_attr_config[:format].present? ? current_attr_config[:format] : options[:datetime_format]
          result[attribute_name] = if attribute_format.to_s == 'standard'
                                     v # standard 保持时间对象原生格式
                                   elsif attribute_format.present?
                                     # 匹配内置的别名格式 (full/min/date/month/year)，否则作为自定义 strftime 字符串处理
                                     if %i[full min date month year].include?(attribute_format.to_sym)
                                       v.strftime("::#{self.class}::DATETIME_#{attribute_format.to_s.upcase}".constantize)
                                     else
                                       v.strftime(attribute_format)
                                     end
                                   else
                                     # 缺省转换为 '%Y-%m-%d %H:%M:%S'
                                     v.strftime(DATETIME_FULL)
                                   end
        else
          # 普通值直接赋值
          result[attribute_name] = v
        end
      end

      # 统一将结果第一层的键名转化为 Symbol 格式
      result.symbolize_keys!

      # 5. 处理嵌套关联对象 (includes)
      format_associations!(result, options)

      result
    end

    private

    # 处理并格式化嵌套关联对象
    # @param [Hash] result 当前实例的输出结果散列
    # @param [Hash] options 包含 :includes 配置的选项散列
    def format_associations!(result, options)
      return unless options[:includes].present? && options[:includes].is_a?(::Hash)

      options[:includes].each do |association_name, assoc_options|
        assoc_options = {} unless assoc_options.is_a?(::Hash)

        # 安全获取关联对象
        next unless respond_to?(association_name)

        assoc_obj = __send__(association_name)

        # 遍历处理关联对象
        if assoc_obj.respond_to?(:map)
          result[association_name.to_sym] = assoc_obj.map do |item|
            item.respond_to?(:instance_info) ? item.instance_info(**assoc_options) : item
          end
        elsif assoc_obj.present?
          result[association_name.to_sym] = assoc_obj.respond_to?(:instance_info) ? assoc_obj.instance_info(**assoc_options) : assoc_obj
        end
      end
    end
  end
end
