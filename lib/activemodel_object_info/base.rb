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
  #   [2026-07-28] 支持通过 Proc / Lambda 完全自定义时间格式化 (shiner527)
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
    # 对象信息输出。主要返回给前端一个可用的散列（会被转化为 JSON 格式）格式的信息并传递给前端。
    #
    # @since 0.1.0 基础功能
    # @since 0.4.0 兼容 Ruby 3.x 关键字参数，支持 :context 与 :includes
    # @since 0.4.2 时间格式化支持 Proc/Lambda 完全自定义
    #
    # @param [Hash] options_hash 设置选项（传统位置参数 Hash），如果传入将被与 keyword_options 合并
    # @param [Hash] keyword_options 设置选项（Ruby 3 关键字参数）
    #
    # @option keyword_options [Symbol, String] :context 场景上下文名称。如果提供，将优先读取 "INSTANCE_INFO_#{context.upcase}" 常量。
    # @option keyword_options [Array<Symbol, Hash>] :attributes 具体每一项输出的设置数组。每个元素既可以是标识符实例也可以是一个散列实例。
    #   如果是标识符实例，则表示输出该属性。如果是一个散列实例，则按照散列中的设定值去生成对应的内容。
    #   散列中支持如下配置项：
    #   - :name (Symbol) 对应的原始字段名或方法名
    #   - :as (Symbol) 别名，输出时会使用该别名代替原始字段名
    #   - :type (Symbol) 当配置为 :abstract 时表示虚拟字段，不再去对象中调用对应的属性
    #   - :filter (Proc, Symbol, Object) 过滤器，如果是 Proc，则通过 instance_exec 执行；若是 Symbol，则调用同名方法；否则直接作为静态值返回
    #   - :format (Symbol, String, Proc) 对于时间字段进行格式化。支持预设 Symbol(:full, :min, :date, :month, :year, :standard)，原生 strftime 字符串，或通过 Proc 自定义输出
    # @option keyword_options [Array<Symbol>] :only 给出具体可以用来输出的字段属性名数组。只有在 only 中的字段才会被输出。
    # @option keyword_options [Array<Symbol>] :except 给出需要被排除输出的字段属性名数组。默认排除 `deleted` 相关的审计字段。
    # @option keyword_options [String, Symbol] :datetime_format 全局的时间格式设置，作用于所有时间类型但会被字段级的 format 覆盖。
    # @option keyword_options [Hash] :includes 需要嵌套输出的关联对象配置，以 Hash 形式递归定义子对象的输出规则（如 `{ profile: { only: [:avatar] } }`）。
    #
    # @example 基本使用
    #   user.instance_info(only: [:id, :name])
    #   # => { id: 1, name: "Alice" }
    #
    # @example 复杂字段重命名与过滤
    #   user.instance_info(
    #     attributes: [
    #       :id,
    #       { name: :first_name, as: :name },
    #       { name: :age, type: :abstract, filter: ->(v) { 2026 - birth_year } }
    #     ]
    #   )
    #   # => { id: 1, name: "Alice", age: 30 }
    #
    # @example 时间自定义格式化
    #   user.instance_info(
    #     attributes: [
    #       { name: :created_at, format: ->(v) { "#{v.year}年#{v.month}月#{v.day}日" } }
    #     ]
    #   )
    #   # => { created_at: "2026年7月28日" }
    #
    # @example 嵌套关联输出
    #   user.instance_info(
    #     only: [:id, :name],
    #     includes: {
    #       profile: { only: [:avatar_url] },
    #       roles: { only: [:id, :role_name] }
    #     }
    #   )
    #   # => { id: 1, name: "Alice", profile: { avatar_url: "..." }, roles: [{ id: 1, role_name: "admin" }] }
    #
    # @return [Hash] 返回处理过的该对象的信息散列，键名统一转化为 Symbol。
    #
    # @raise [NoMethodError] 当尝试获取未定义的属性，且未将该属性设为 `type: :abstract` 或配置 `filter` 时可能抛出。
    #
    def instance_info(options_hash = nil, **keyword_options)
      # 合并传统参数与关键字参数，完美兼容 Ruby 2.x 的 Hash 传参和 Ruby 3.x 的 **kwargs 传参
      options = (options_hash || {}).merge(keyword_options)

      # 尝试获取当前类上配置的常量作为默认选项
      # 优先级：传入的参数 options > 场景常量 INSTANCE_INFO_#{CONTEXT} > 默认常量 INSTANCE_INFO
      if options.blank? || (options.keys.map(&:to_sym) == [:context] && options[:context].present?)
        context_name = options[:context].to_s.upcase if options[:context].present?

        # 尝试寻找带场景的常量
        options = ("#{self.class}::INSTANCE_INFO_#{context_name}".safe_constantize if context_name.present?)

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
      # 并且当前并没有匹配到任何场景常量，我们需要将 only_attributes 中的字段视为基础配置，以确保只包含这几个字段的正常输出
      attribute_configs = only_attributes.map { |attr| { name: attr } } if attribute_configs.empty? && only_attributes.present?

      # 补丁 2：如果在处理完毕后，attribute_configs 仍然为空，并且 output_attributes 存在
      # 则说明我们正在执行类似 default options 的全量输出或者包含了所有字段的嵌套输出
      # 此时，我们需要基于 output_attributes 自动生成 attribute_configs，但需要保留 options[:attributes] 中已经配置了 format 等逻辑的字段配置
      if attribute_configs.empty? && output_attributes.present?
        # 取出最初预设在 options 里的属性配置
        preset_configs = options[:attributes] || []

        # 获取 options 中显式定义了的所有字段的原始名和别名
        preset_attr_names = preset_configs.flat_map do |config|
          case config
          when ::Hash
            [config[:name], config[:as]].compact.map(&:to_sym)
          when ::Symbol, ::String
            config.to_sym
          end
        end.compact.uniq

        supplementary_configs = (output_attributes - preset_attr_names).map { |attr| { name: attr } }

        # 将预设的规则配置和自动补充的基础配置合并，作为最终的 attribute_configs
        # 注意：为了避免重复处理以及处理顺序问题，我们统一使用预先配置，并在末尾追加没有配置的字段
        attribute_configs = preset_configs + supplementary_configs

        # 移除 attribute_configs 中的重复项 (如果存在)
        attribute_configs.uniq!
      end

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

        # 获取真正对应的属性的名称和其值
        k = raw_name
        # 当类型为抽象类时，是不会有对应的方法和属性的，因此直接设置为 nil 并期待之后的 filter 等规则来生成实际值。
        v = current_attr_config[:type] == :abstract ? nil : __send__(k)

        # 跳过条件：既不在最终输出名单中，也不是显式声明的 abstract/method 虚拟字段
        # 注意：需要同时判断别名(attribute_name)和原名(k)是否在需要输出的列表中
        next unless output_attributes.include?(attribute_name) || output_attributes.include?(k) || %i[abstract method].include?(current_attr_config[:type])

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
                                   elsif attribute_format.is_a?(::Proc)
                                     # 支持传入 Lambda 或 Proc 进行完全自定义的格式化
                                     instance_exec(v, &attribute_format)
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

    #
    # 处理并格式化嵌套关联对象。
    #
    # @api private
    #
    # @note 该方法仅被 `instance_info` 内部调用，用于将配置中 `includes` 的选项应用到实际的关联对象上。
    #   之所以保持私有（private），是因为此方法直接修改了 `instance_info` 输出的 `result` 散列，
    #   其行为和状态与 `instance_info` 的上下文深度绑定，单独对外暴露并无实际意义，反而会破坏对象的封装性。
    #
    # @since 0.4.0
    #
    # @param [Hash] result 当前实例的输出结果散列，关联对象的数据会被注入到该散列中
    # @param [Hash] options 包含 `:includes` 配置的选项散列
    #
    # @return [void]
    #
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
