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
    it 'created columns' do
      obj.operation_columns(:created)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'allow create operator column explicitly' do
      obj.operation_columns(:created, with_operator: true)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'disallow create operator column' do
      obj.operation_columns(:created, with_operator: false)
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'allow create timestamp column explicitly' do
      obj.operation_columns(:created, with_timestamp: true)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'disallow create timestamp column' do
      obj.operation_columns(:created, with_timestamp: false)
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
    end

    it 'use operator column prefix' do
      obj.operation_columns(:created, operator_prefix: :order_)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('order_created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'use operator column suffix explicitly' do
      obj.operation_columns(:created, operator_suffix: :_user)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_user'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'blank operator field with blank prefix and suffix' do
      obj.operation_columns('', operator_suffix: '')
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'use timestamp column prefix' do
      obj.operation_columns(:created, timestamp_prefix: :order_)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('order_created_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'use timestamp column suffix explicitly' do
      obj.operation_columns(:created, timestamp_suffix: :_time)
      columns = obj.columns
      expect(columns.size).to eq(2)
      expect(columns[0]).to a_collection_containing_exactly(eq('created_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('created_time'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

    it 'blank timestamp field with blank prefix and suffix' do
      obj.operation_columns('', timestamp_suffix: '')
      columns = obj.columns
      expect(columns.size).to eq(1)
      expect(columns.first).to a_collection_containing_exactly(eq('_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
    end

    it 'multiple fields' do
      obj.operation_columns(:arg1, :arg2)
      columns = obj.columns
      expect(columns.size).to eq(4)
      expect(columns[0]).to a_collection_containing_exactly(eq('arg1_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[1]).to a_collection_containing_exactly(eq('arg1_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
      expect(columns[2]).to a_collection_containing_exactly(eq('arg2_by'), eq(:bigint), a_hash_including({ index: eq(true), comment: eq('操作人') }))
      expect(columns[3]).to a_collection_containing_exactly(eq('arg2_at'), eq(:datetime), a_hash_including({ comment: eq('操作时间戳') }))
    end

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
