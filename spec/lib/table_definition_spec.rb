# frozen_string_literal: true

module ActivemodelObjectInfo
  class TestTableDefinition
    include TableDefinition

    attr_accessor :columns

    def column(*args)
      # 将创建的内容参数放入单类属性中保存
      if columns.blank?
        self.columns = [args]
      else
        columns << args
      end
    end
  end
end

RSpec.describe ::ActivemodelObjectInfo::TestTableDefinition do
  let(:obj) { described_class.new }

  # 检测生成操作字段列的实例方法
  describe '#operation_columns' do
    # 验证场景：只传入动作名 :created 的基础调用
    # 核心功能点：默认开启生成 operator 和 timestamp 字段，且使用默认的 _by 和 _at 后缀
    # 预期结果：生成 created_by(bigint) 和 created_at(datetime) 两个字段
    it 'created columns' do
      obj.operation_columns(:created)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：显式开启生成操作人字段
    # 核心功能点：参数 with_operator: true 的行为
    # 预期结果：与基础调用一致，生成 created_by
    it 'allow create operator column explicitly' do
      obj.operation_columns(:created, with_operator: true)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：显式关闭生成操作人字段
    # 核心功能点：参数 with_operator: false 的行为
    # 预期结果：只生成 created_at，不生成 created_by
    it 'disallow create operator column' do
      obj.operation_columns(:created, with_operator: false)
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：显式开启生成时间戳字段
    # 核心功能点：参数 with_timestamp: true 的行为
    # 预期结果：与基础调用一致，生成 created_at
    it 'allow create timestamp column explicitly' do
      obj.operation_columns(:created, with_timestamp: true)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：显式关闭生成时间戳字段
    # 核心功能点：参数 with_timestamp: false 的行为
    # 预期结果：只生成 created_by，不生成 created_at
    it 'disallow create timestamp column' do
      obj.operation_columns(:created, with_timestamp: false)
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
    end

    # 验证场景：自定义操作人前缀
    # 核心功能点：operator_prefix 参数的应用
    # 预期结果：生成 order_created_by
    it 'use operator column prefix' do
      obj.operation_columns(:created, operator_prefix: :order_)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('order_created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：自定义操作人后缀
    # 核心功能点：operator_suffix 参数的应用（覆盖默认的 _by）
    # 预期结果：生成 created_user
    it 'use operator column suffix explicitly' do
      obj.operation_columns(:created, operator_suffix: :_user)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_user'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：空动作名和空操作人后缀
    # 核心功能点：边界条件处理，若最终字段名为空不应生成
    # 预期结果：因 operator_column_name 最终为空（present? 为 false），只生成了 _at 字段
    it 'blank operator field with blank prefix and suffix' do
      obj.operation_columns('', operator_suffix: '')
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：自定义时间戳前缀
    # 核心功能点：timestamp_prefix 参数的应用
    # 预期结果：生成 order_created_at
    it 'use timestamp column prefix' do
      obj.operation_columns(:created, timestamp_prefix: :order_)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('order_created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：自定义时间戳后缀
    # 核心功能点：timestamp_suffix 参数的应用（覆盖默认的 _at）
    # 预期结果：生成 created_time
    it 'use timestamp column suffix explicitly' do
      obj.operation_columns(:created, timestamp_suffix: :_time)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_time'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：空动作名和空时间戳后缀
    # 核心功能点：边界条件处理，若最终字段名为空不应生成
    # 预期结果：因 timestamp_column_name 为空，只生成了 _by 字段
    it 'blank timestamp field with blank prefix and suffix' do
      obj.operation_columns('', timestamp_suffix: '')
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
    end

    # 验证场景：同时传入多个动作名
    # 核心功能点：支持可变参数 *fields，一次性生成多组字段
    # 预期结果：生成 arg1_by, arg1_at, arg2_by, arg2_at 供四个字段
    it 'multiple fields' do
      obj.operation_columns(:arg1, :arg2)
      columns = obj.columns
      expect(columns.size).to eq(4)
      expect(columns[0]).to a_collection_containing_exactly(eq('arg1_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('arg1_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
      expect(columns[2]).to a_collection_containing_exactly(eq('arg2_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[3]).to a_collection_containing_exactly(eq('arg2_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：混合多字段及多种自定义配置
    # 核心功能点：多字段同时应用前后缀及开关选项
    # 预期结果：只生成 order_arg1_user 和 order_arg2_user
    it 'full arguments' do
      obj.operation_columns(:arg1, :arg2, with_timestamp: false, operator_prefix: 'order_', operator_suffix: '_user')
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('order_arg1_user'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('order_arg2_user'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
    end
  end

  # 检测快速批量生成字段列的实例方法
  describe '#generate_operations' do
    # 验证场景：无参数调用默认配置
    # 核心功能点：默认生成 created/updated/deleted 三大生命周期字段套装
    # 预期结果：生成 7 个字段（包含单独的 deleted 状态标记字段）
    it 'default no any argument' do
      obj.generate_operations
      columns = obj.columns
      expect(columns.size).to eq(7)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
      expect(columns[2]).to a_collection_containing_exactly(eq('updated_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[3]).to a_collection_containing_exactly(eq('updated_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
      expect(columns[4]).to a_collection_containing_exactly(eq('deleted'), eq(:integer), a_hash_including({ default: eq(0), comment: eq('删除标记') }))
      expect(columns[5]).to a_collection_containing_exactly(eq('deleted_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[6]).to a_collection_containing_exactly(eq('deleted_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    # 验证场景：自定义动作名称集合
    # 核心功能点：只对传入的自定义动作进行审计字段生成
    # 预期结果：生成 submitted_by, submitted_at, approved_by, approved_at 共四个字段
    it 'use custom fields' do
      obj.generate_operations('submitted', :approved)
      columns = obj.columns
      expect(columns.size).to eq(4)
      expect(columns[0]).to a_collection_containing_exactly(eq('submitted_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('submitted_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
      expect(columns[2]).to a_collection_containing_exactly(eq('approved_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[3]).to a_collection_containing_exactly(eq('approved_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end
  end
end
