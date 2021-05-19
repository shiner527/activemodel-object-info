# frozen_string_literal: true

module ActivemodelObjectInfo
  #
  # 通用的设置操作项相关的模型方法和处理。
  #
  # @author shiner527 <shiner527@hotmail.com>
  #
  module Base
    #
    # 对象信息输出。主要返回给前端一个可用的散列（会被转化为JSON格式）格式的信息并传递给前端。
    #
    # @param [Hash] options 设置选项
    # @option options [Array<Symbol, Hash>] :attributes 具体每一项输出的设置数组。每个元素既可以是标识符实例也可以是一个散列实例。
    #  如果是标识符实例，则表示输出该属性。如果是一个散列实例，则按照散列中的设定值去生成对应的内容。
    # @option options [Array<Symbol>] :only 给出具体可以用来输出的字段属性名数组。
    #
    # @return [Hash] 返回的处理过的该对象的信息散列。
    #
    def instance_info(**options)
      # puts "ARGS: #{args}, OPTIONS: #{options}"
      result = {}
      # 仅包含的字段
      only_attributes = (options[:only] || []).map(&:to_sym)
      # 要排除的字段
      # 默认不包含 :deleted, :deleted_by 和 :deleted_at 三个字段
      default_deleted_column = ::Constants::Base::TABLE_COLUMN_DELETE_COLUMN rescue 'deleted'
      default_except_attrs = [
        default_deleted_column,
        "#{default_deleted_column}_by",
        "#{default_deleted_column}_at",
      ]
      except_attributes = (options[:except] || default_except_attrs).map(&:to_sym)
      # 字段的具体属性设置
      attribute_configs = options[:attributes] || []
      # 计算要输出的参数名称
      output_attributes = attribute_names.map(&:to_sym)
      output_attributes &= only_attributes if only_attributes.present?
      output_attributes -= except_attributes

      # puts "Excepts: #{except_attributes}, Only: #{only_attributes}, Output: #{output_attributes}"
      # 这里保证了要引入的类中含有 attributes 方法，且为 Hash 类型
      attribute_configs.each do |attr_config|
        # 如果设置项单纯是字符串或者标识符的情况
        if [::String, ::Symbol].any? { |attr_class| attr_config.is_a?(attr_class) }
          attribute_name = attr_config.to_sym
          current_attr_config = {}
        elsif attr_config.is_a?(::Hash) # 如果设置项为一个散列
          current_attr_config = attr_config.deep_symbolize_keys
          attribute_name = current_attr_config[:name]
        else # 如果不是指定的类型，则跳过进行下一项
          next
        end
        # 输出的参数名称，如果用户给出了 as 指定，优先用用户给定的，否则默认用属性名
        raw_name = current_attr_config[:as].present? ? current_attr_config[:as].to_sym : attribute_name
        # 过滤器输出字段，如果给定了一个块，则使用用户指定的，否则默认为没有过滤器
        filter = current_attr_config[:filter]

        # 获取真正对应的属性的名称和其值
        k = raw_name
        # 当类型为抽象类时，是不会有对应的方法和属性的，因此直接设置为 nil 并期待之后的 filter 等规则来生成实际值。
        v = current_attr_config[:type] == :abstract ? nil : __send__(k)

        # puts "instance attributes #{k}: #{v}(#{v.class.name})"
        # 如果不是要输出的字段则跳过，或者如果不是给出type设置项为 :method 或者 :abstract 也跳过。
        next unless output_attributes.include?(k) || %i[abstract method].include?(current_attr_config[:type])

        # 赋值。如果有过滤器，优先使用过滤器
        if filter.present?
          result[attribute_name] = case filter
                                   when ::Proc
                                     instance_exec(v, &filter)
                                   when ::Symbol
                                     __send__(filter)
                                   else
                                     filter
                                   end
        # 如果值是时间类别的字段，默认转换为时间日期格式的字符串
        elsif [::Date, ::Time, ::DateTime].any? { |time_class| v.is_a?(time_class) }
          # 时间日期格式设定，优先使用当前字段自定义，否则使用通用自定义，最后使用默认格式
          attribute_format = current_attr_config[:format].present? ? current_attr_config[:format] : options[:datetime_format]
          result[attribute_name] = if attribute_format.to_s == 'standard' # 会被转换为标准时间日期格式
                                     v
                                   elsif attribute_format.present? # 按照设定的 format_date 方法的格式
                                     v.format_date(attribute_format.to_sym)
                                   else # 默认使用 'yyyy-MM-dd hh:mm:ss' 的格式
                                     v.format_date(:full)
                                   end
        else # 其他值类型默认赋值自己
          result[attribute_name] = v
        end
      end

      # 过滤第一层键名为符号并返回
      result.symbolize_keys!
    end
  end
end
