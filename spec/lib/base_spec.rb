# frozen_string_literal: true

module ActivemodelObjectInfo
  class TestBase
    include ActivemodelObjectInfo::Base

    INSTANCE_INFO = {
      attributes: [
        :id, :name, :created_by, :updated_by, :deleted_by,
        { name: :created_at },
        { name: :updated_at, format: :date },
      ],
    }.freeze

    attr_accessor :arg1, :arg2, :arg3, :id, :name, :deleted, :deleted_at, :deleted_by, :created_by, :created_at, :updated_by, :updated_at

    def attribute_names
      %i[arg1 arg2 arg3 id name deleted deleted_at deleted_by created_by created_at updated_by updated_at]
    end

    def attributes
      attribute_names.to_h { |attr_name| [attr_name, __send__(attr_name)] }
    end

    def test_method
      "id = #{id} and name = #{name}"
    end
  end
end

RSpec.describe ActivemodelObjectInfo::TestBase do
  let(:obj) { described_class.new }
  let(:full_time_reg) { /^\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[1-2]\d|3[0-1])\s\d{2}:\d{2}:\d{2}$/ }
  let(:only_date_reg) { /\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[1-2]\d|3[0-1])$/ }

  # 版本检测
  describe 'Version' do
    # 验证场景：加载 Gem 时的基础版本号常量校验
    # 核心功能点：确保 Version::VERSION 被正确定义并同步到了最新版本
    # 预期结果：版本号应严格等于 '0.4.0'
    it 'correct current version' do
      expect(::ActivemodelObjectInfo::Version::VERSION).to eq('0.4.0')
    end
  end

  # 对信息进行测试
  describe '#instance_info' do
    context 'when use default options' do
      let(:inst) do
        {
          id: 1000, name: 'test-name', created_at: Time.now,
          updated_at: Time.now, deleted_at: Time.now - 1.day,
        }.each do |k, v|
          obj.__send__("#{k}=", v)
        end
        obj
      end

      # 验证场景：不传入任何参数直接调用 instance_info
      # 核心功能点：触发 options.blank? 逻辑，回退使用类上的 INSTANCE_INFO 常量，并默认过滤掉 deleted 等字段
      # 预期结果：正常返回 Hash，时间字段被默认转为字符串格式，敏感字段（deleted类）被自动排除
      it 'default options worked' do
        info = inst.instance_info
        expect(info).to be_an_instance_of(Hash)
        expect(info[:id]).to eq(1000)
        expect(info[:name]).to eq('test-name')
        expect(info[:created_at]).to be_an_instance_of(::String).and(match(full_time_reg))
        expect(info[:updated_at]).to be_an_instance_of(::String).and(match(only_date_reg))
        expect(info.key?(:deleted_by)).to eq(false)
        expect(info.key?(:deleted_at)).to eq(false)
        expect(info.key?(:deleted)).to eq(false)
      end
    end

    context 'with diverse processor type' do
      let(:inst) do
        {
          id: 1000, name: 'test-name', created_by: 100,
          created_at: Time.now, updated_at: Time.now,
          deleted_at: Time.now - 1.day,
        }.each do |k, v|
          obj.__send__("#{k}=", v)
        end
        obj
      end

      # 验证场景：Ruby 2.x 风格的参数传递方式
      # 核心功能点：验证重构后的签名 options_hash = nil 能够正确接收并合并传统 Hash
      # 预期结果：按传入的 :only 白名单正常输出 id 和 name，created_by 被过滤
      it 'supports legacy hash argument' do
        options = { only: %i[id name] }
        info = inst.instance_info(options)
        expect(info[:id]).to eq(1000)
        expect(info[:name]).to eq('test-name')
        expect(info.key?(:created_by)).to eq(false)
      end

      # 验证场景：Ruby 3.x 风格的关键字参数传递方式
      # 核心功能点：验证重构后的签名 **keyword_options 能够正确接收 kwargs 并应用
      # 预期结果：同上，按 kwargs 配置正常输出并过滤多余字段
      it 'supports ruby 3 keyword arguments' do
        info = inst.instance_info(only: %i[id name])
        expect(info[:id]).to eq(1000)
        expect(info[:name]).to eq('test-name')
        expect(info.key?(:created_by)).to eq(false)
      end

      # 验证场景：显式将 Hash 解构为关键字参数传递
      # 核心功能点：验证应对显式解构操作时参数不会丢失或报错，确保最大兼容性
      # 预期结果：同上，正确提取参数并输出对应字段
      it 'supports explicit splat keyword arguments' do
        options = { only: %i[id name] }
        info = inst.instance_info(**options)
        expect(info[:id]).to eq(1000)
        expect(info[:name]).to eq('test-name')
        expect(info.key?(:created_by)).to eq(false)
      end

      # 验证场景：复杂的自定义参数传入
      # 核心功能点：验证同时使用 :only 白名单和 :attributes 覆盖规则
      # 预期结果：返回白名单中交集的字段，且 attributes 中指定的格式化规则（format: :standard）生效
      it 'only options' do
        options = {
          only: %i[id name created_at],
          attributes: [
            :id, :name, :created_by,
            { name: :created_at, format: :standard },
          ],
        }
        info = inst.instance_info(options)
        expect(info[:id]).to eq(1000)
        expect(info[:name]).to eq('test-name')
        expect(info[:created_at]).to be_an_instance_of(::Time)
        expect(info.key?(:created_by)).to eq(false)
      end

      # 验证场景：传入非法类型的 attributes 配置（如数字、布尔值、数组等）
      # 核心功能点：容错处理逻辑（遇到非法类型配置时 next 跳过）
      # 预期结果：非法配置被丢弃，最终返回空 Hash
      it 'invalid attribute config type' do
        options = { attributes: [123, true, [1, 2, 3]] }
        info = inst.instance_info(options)
        expect(info).to eq({})
      end

      # 验证场景：使用 :as 参数为输出字段重命名别名
      # 核心功能点：验证从对象内部取值（原名 name），并重命名输出（新名 new_name）
      # 预期结果：输出 Hash 中存在 :new_name 且值为 test-name，不存在原名 :name
      it 'use specific attribute name' do
        options = { attributes: [{ name: :new_name, as: :name }] }
        info = inst.instance_info(options)
        expect(info[:new_name]).to eq('test-name')
        expect(info.key?(:name)).to eq(false)
      end

      # 验证场景：自定义时间日期格式化字符串
      # 核心功能点：验证时间字段在使用原生 strftime 字符串格式化时的正确性
      # 预期结果：时间字段返回指定 '%Y/%m/%d' 格式的字符串
      it 'use original strftime date format' do
        options = { attributes: [{ name: :created_at, format: '%Y/%m/%d' }] }
        info = inst.instance_info(options)
        expect(info[:created_at]).to match(%r{^\d{4}/\d{2}/\d{2}$})
      end

      # 验证场景：通过 Proc 闭包对值进行过滤处理
      # 核心功能点：验证 filter 参数接收 Proc 时，能在实例上下文中执行（instance_exec）
      # 预期结果：字段值被正确改写（"#{id}-#{v}"）
      it 'normal lambda filter' do
        options = { attributes: [{ name: :name, filter: ->(v) { "#{id}-#{v}" } }] }
        info = inst.instance_info(options)
        expect(info[:name]).to eq('1000-test-name')
      end

      # 验证场景：通过 Symbol 调用同名方法对值进行处理
      # 核心功能点：验证 filter 参数接收 Symbol 时，能正确调用实例上的对应方法作为返回值
      # 预期结果：调用了实例方法 test_method，返回格式化的字符串
      it 'filter type is symbol' do
        options = { attributes: [{ name: :label, as: :name, filter: :test_method }] }
        info = inst.instance_info(options)
        expect(info[:label]).to eq('id = 1000 and name = test-name')
      end

      # 验证场景：通过传入任意常量/变量作为静态返回值
      # 核心功能点：验证 filter 接收非 Proc、非 Symbol 时，直接作为硬编码默认值返回
      # 预期结果：无论对象原本值为多少，统一输出传入的静态数组
      it 'other type filter' do
        options = { attributes: [{ name: :created_by, filter: [100, 200, 300] }] }
        info = inst.instance_info(options)
        expect(info[:created_by]).to eq([100, 200, 300])
      end

      # 验证场景：定义并输出虚拟字段（Abstract Type）
      # 核心功能点：验证当字段不是数据库列或 attr_accessor，仅用于根据现有字段合成新内容时，结合 abstract 与 filter 使用的表现
      # 预期结果：能正常调用 filter 逻辑合成字段值，且不抛出方法未定义异常
      it 'with abstract type' do
        options = { attributes: [{ name: :xyz, type: :abstract, filter: ->(*) { id + created_by } }] }
        info = inst.instance_info(options)
        expect(info[:xyz]).to eq(1100)
      end
    end
  end
end
