# frozen_string_literal: true

#
# 时间类型相关类通用实例方法定义模块。
#
# @author shiner527 <shiner527@hotmail.com>
#
module TimeInstance
  #
  # 时间格式化为指定的字符串。
  #
  # @param [Symbol] type 指定需要转换的具体格式。默认为 +:date+ 类型的格式。
  #
  # @return [String] 返回转换后的字符串。
  #
  def format_date(type = :date)
    case type
    when :full
      strftime('%Y-%m-%d %H:%M:%S')
    when :min
      strftime('%Y-%m-%d %H:%M')
    when :date
      strftime('%Y-%m-%d')
    when :year
      strftime('%Y')
    end
  end
end

#
# 扩展 Date 类
#
class Date
  include ::TimeInstance
end

#
# 扩展 Time 类
#
class Time
  include ::TimeInstance
end

#
# 扩展 DateTime 类
#
class DateTime
  include ::TimeInstance
end

#
# 扩展 Array 类
#
class Array
  #
  # 找到数组中为空的元素，并将去掉空元素的结果返回为一个新数组。空的定义由 +blank?+ 方法确定。本方法<b>不会改变</b>数组自身。
  #
  # @return [Array] 返回不包含空元素的数组作为结果。
  #
  def compact_blank
    result = []
    each { |item| result << item unless item.blank? }
    result
  end

  #
  # 去掉空元素并将去掉后的数组作为结果返回。空的定义由 +blank?+ 方法确定。本方法<b>会改变</b>数组自身。
  #
  # @return [Array] 返回不包含空元素的数组作为结果。
  #
  def compact_blank!
    delete_if(&:blank?)
  end
end

#
# 扩展 Array 类
#
class Hash
  #
  # 找到散列中键值对的值为空的元素，并将去掉这样的键值对的结果返回为一个新散列。空的定义由 +blank?+ 方法确定。本方法<b>不会改变</b>散列自身。
  #
  # @return [Array] 返回不包含键值对中值为空元素的散列作为结果。
  #
  def compact_blank
    result = {}
    each { |k, v| result[k] = v unless v.blank? }
    result
  end

  #
  # 去掉散列中键值对的值为空的键值对，并将去掉后的散列作为结果返回。空的定义由 +blank?+ 方法确定。本方法<b>会改变</b>散列自身。
  #
  # @return [Array] 返回不包含键值对中值为空元素的散列作为结果。
  #
  def compact_blank!
    delete_if { |_k, v| v.blank? }
  end
end
