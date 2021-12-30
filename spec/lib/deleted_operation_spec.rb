# frozen_string_literal: true

module ActivemodelObjectInfo
  class TestDeletedOperation
    class << self
      attr_accessor :default_scope_created

      def default_scope
        self.default_scope_created = true
      end
    end

    attr_accessor :updated_at, :updated_by, :deleted, :deleted_at, :deleted_by, :deleted_arguments

    def save(*args)
      self.updated_at = Time.now if args.last.is_a?(::Hash) && args.last.try(:[], :touch)
      self.deleted_arguments = { method: :save, arguments: args }
    end

    def save!(*args)
      self.updated_at = Time.now if args.last.is_a?(::Hash) && args.last.try(:[], :touch)
      self.deleted_arguments = { method: :save!, arguments: args }
    end

    include DeletedOperation
  end

  class TestDeletedOperationChild
    class << self
      attr_accessor :default_scope_created

      def default_scope
        self.default_scope_created = true
      end
    end

    attr_accessor :deleted, :updated_at, :deleted_arguments

    def save(*args)
      self.updated_at = Time.now if args.last.is_a?(::Hash) && args.last.try(:[], :touch)
      self.deleted_arguments = { method: :save, arguments: args }
    end

    def save!(*args)
      self.updated_at = Time.now if args.last.is_a?(::Hash) && args.last.try(:[], :touch)
      self.deleted_arguments = { method: :save!, arguments: args }
    end

    include DeletedOperation
  end
end

RSpec.describe ::ActivemodelObjectInfo::TestDeletedOperation do
  let(:obj) do
    r = described_class.new
    r.updated_at = Time.now
    r.updated_by = 1
    r
  end

  # 检验混入
  describe '.include' do
    it 'included succesfully' do
      expect(described_class.default_scope_created).to eq(true)
      obj
      expect(obj).to respond_to(:delete_block)
      expect(obj).to respond_to(:soft_delete)
      expect(obj).to respond_to(:soft_delete!)
    end
  end

  # 检测删除模块
  describe '#soft_delete' do
    it 'normal call with user id' do
      obj.soft_delete(user_id: 1234)
      expect(obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(obj.deleted_arguments[:method]).to eq(:save)
      expect(obj.deleted_arguments[:arguments]).to eq([{ touch: nil }])
      expect(obj.deleted_at).to be_an_instance_of(::Time)
      expect(obj.deleted_by).to eq(1234)
      expect(obj.deleted).to eq(1)
    end

    it 'disallow refresh updated explicitly' do
      obj.soft_delete(user_id: 1234, refresh_updated: false)
      expect(obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(obj.deleted_arguments[:method]).to eq(:save)
      expect(obj.deleted_arguments[:arguments]).to eq([{ touch: false }])
      expect(obj.deleted_at).to be_an_instance_of(::Time)
      expect(obj.deleted_by).to eq(1234)
      expect(obj.deleted).to eq(1)
      expect(obj.updated_by).to eq(1)
      expect(obj.updated_at).to be_an_instance_of(::Time)
      expect(obj.updated_at).to be < obj.deleted_at
    end

    it 'allow refresh updated' do
      old_updated_at = obj.updated_at
      obj.soft_delete(user_id: 1234, refresh_updated: true)
      expect(obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(obj.deleted_arguments[:method]).to eq(:save)
      expect(obj.deleted_arguments[:arguments]).to eq([{ touch: true }])
      expect(obj.deleted_at).to be_an_instance_of(::Time)
      expect(obj.deleted_by).to eq(1234)
      expect(obj.deleted).to eq(1)
      expect(obj.updated_by).to eq(1234)
      expect(obj.updated_at).to be_an_instance_of(::Time)
      expect(obj.updated_at).to be > old_updated_at
    end

    it 'no fields of deleted operator and timestamps' do
      inst = ::ActivemodelObjectInfo::TestDeletedOperationChild.new
      inst.updated_at = Time.now
      old_updated_at = inst.updated_at
      inst.soft_delete(user_id: 1234, refresh_updated: true)
      expect(inst.deleted_arguments).to be_an_instance_of(::Hash)
      expect(inst.deleted_arguments[:method]).to eq(:save)
      expect(inst.deleted_arguments[:arguments]).to eq([{ touch: true }])
      expect(inst.updated_at).to be_an_instance_of(::Time)
      expect(inst.updated_at).to be > old_updated_at
    end

    it 'no user id' do
      expect { obj.soft_delete }.to raise_error do |error|
        expect(error).to be_an_instance_of(::ArgumentError)
        expect(error.message).to eq('Must give user id!')
      end
    end
  end

  # 检测强制删除模块
  describe '#soft_delete!' do
    it 'call with correct arguments' do
      obj.soft_delete!(user_id: 1234)
      expect(obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(obj.deleted_arguments[:method]).to eq(:save!)
      expect(obj.deleted_arguments[:arguments]).to eq([{ touch: nil }])
      expect(obj.deleted_at).to be_an_instance_of(::Time)
      expect(obj.deleted_by).to eq(1234)
      expect(obj.deleted).to eq(1)
    end
  end
end
