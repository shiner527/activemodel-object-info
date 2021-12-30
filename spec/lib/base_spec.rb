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
    it 'correct current version' do
      expect(::ActivemodelObjectInfo::Version::VERSION).to eq('0.2.0')
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

      it 'invalid attribute config type' do
        options = { attributes: [123, true, [1, 2, 3]] }
        info = inst.instance_info(options)
        expect(info).to eq({})
      end

      it 'use specific attribute name' do
        options = { attributes: [{ name: :new_name, as: :name }] }
        info = inst.instance_info(options)
        expect(info[:new_name]).to eq('test-name')
        expect(info.key?(:name)).to eq(false)
      end

      it 'use original strftime date format' do
        options = { attributes: [{ name: :created_at, format: '%Y/%m/%d' }] }
        info = inst.instance_info(options)
        expect(info[:created_at]).to match(%r{^\d{4}/\d{2}/\d{2}$})
      end

      it 'normal lambda filter' do
        options = { attributes: [{ name: :name, filter: ->(v) { "#{id}-#{v}" } }] }
        info = inst.instance_info(options)
        expect(info[:name]).to eq('1000-test-name')
      end

      it 'filter type is symbol' do
        options = { attributes: [{ name: :label, as: :name, filter: :test_method }] }
        info = inst.instance_info(options)
        expect(info[:label]).to eq('id = 1000 and name = test-name')
      end

      it 'other type filter' do
        options = { attributes: [{ name: :created_by, filter: [100, 200, 300] }] }
        info = inst.instance_info(options)
        expect(info[:created_by]).to eq([100, 200, 300])
      end

      it 'with abstract type' do
        options = { attributes: [{ name: :xyz, type: :abstract, filter: ->(*) { id + created_by } }] }
        info = inst.instance_info(options)
        expect(info[:xyz]).to eq(1100)
      end
    end
  end
end
