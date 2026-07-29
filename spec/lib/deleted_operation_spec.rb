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
    # 验证场景：模块 include 到宿主类时
    # 核心功能点：验证 `included` 钩子是否成功执行并注入了预期的方法和作用域
    # 预期结果：类方法 default_scope 被调用，实例获得了 delete_block、soft_delete、soft_delete! 以及对应的 restore 方法
    it 'included succesfully' do
      expect(described_class.default_scope_created).to eq(true)
      obj
      expect(obj).to respond_to(:delete_block)
      expect(obj).to respond_to(:soft_delete)
      expect(obj).to respond_to(:soft_delete!)
      expect(obj).to respond_to(:restore_block)
      expect(obj).to respond_to(:restore)
      expect(obj).to respond_to(:restore!)
    end
  end

  # 检测删除模块
  describe '#soft_delete' do
    # 验证场景：正常执行软删除
    # 核心功能点：必须传入 user_id，默认使用 save(touch: nil)
    # 预期结果：审计字段 deleted_at, deleted_by 被赋值，deleted 标记字段被置为 1，底层调用 save
    it 'normal call with user id' do
      obj.soft_delete(user_id: 1234)
      expect(obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(obj.deleted_arguments[:method]).to eq(:save)
      expect(obj.deleted_arguments[:arguments]).to eq([{ touch: nil }])
      expect(obj.deleted_at).to be_an_instance_of(::Time)
      expect(obj.deleted_by).to eq(1234)
      expect(obj.deleted).to eq(1)
    end

    # 验证场景：显式禁止刷新 updated_at 时间
    # 核心功能点：传入 refresh_updated: false 时
    # 预期结果：updated_by 不变，updated_at 不会被刷新，save 接收 touch: false
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

    # 验证场景：显式要求刷新 updated_at 时间
    # 核心功能点：传入 refresh_updated: true 时
    # 预期结果：除了删除字段外，updated_by 会被设为 user_id，updated_at 时间更新，save 接收 touch: true
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

    # 验证场景：宿主类缺少审计字段时执行软删除
    # 核心功能点：验证 respond_to? 安全判断，防止因缺少 deleted_by, deleted_at 字段导致报错
    # 预期结果：依然能正常执行软删除流程并调用 save(touch: true)
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

    # 验证场景：调用软删除未传入 user_id
    # 核心功能点：验证强制审计参数 user_id 的限制
    # 预期结果：抛出 ArgumentError 'Must give user id!'
    it 'no user id' do
      expect { obj.soft_delete }.to raise_error do |error|
        expect(error).to be_an_instance_of(::ArgumentError)
        expect(error.message).to eq('Must give user id!')
      end
    end
  end

  # 检测强制删除模块
  describe '#soft_delete!' do
    # 验证场景：使用严格模式 soft_delete! 进行软删除
    # 核心功能点：底层调用的持久化方法必须是 save!
    # 预期结果：其他字段设置与 soft_delete 一致，但持久化调用变为 save!
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

  # 检测恢复模块
  describe '#restore' do
    let(:deleted_obj) do
      obj.soft_delete(user_id: 1234)
      obj
    end

    # 验证场景：正常执行软删除恢复
    # 核心功能点：清除 deleted_by 和 deleted_at，将 deleted 状态还原
    # 预期结果：删除审计字段变为空，deleted 为 0，底层调用 save
    it 'normal call' do
      deleted_obj.restore
      expect(deleted_obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(deleted_obj.deleted_arguments[:method]).to eq(:save)
      expect(deleted_obj.deleted_arguments[:arguments]).to eq([{ touch: nil }])
      expect(deleted_obj.deleted_at).to be_nil
      expect(deleted_obj.deleted_by).to be_nil
      expect(deleted_obj.deleted).to eq(0)
    end

    # 验证场景：恢复时要求刷新更新时间并记录更新人
    # 核心功能点：传入 user_id 和 refresh_updated: true 时
    # 预期结果：除了恢复字段外，updated_by 会被更新，updated_at 时间更新
    it 'allow refresh updated with user_id' do
      old_updated_at = deleted_obj.updated_at
      deleted_obj.restore(user_id: 5678, refresh_updated: true)
      expect(deleted_obj.deleted_arguments[:method]).to eq(:save)
      expect(deleted_obj.deleted_arguments[:arguments]).to eq([{ touch: true }])
      expect(deleted_obj.deleted_at).to be_nil
      expect(deleted_obj.deleted_by).to be_nil
      expect(deleted_obj.deleted).to eq(0)
      expect(deleted_obj.updated_by).to eq(5678)
      expect(deleted_obj.updated_at).to be_an_instance_of(::Time)
      expect(deleted_obj.updated_at).to be > old_updated_at
    end
  end

  # 检测强制恢复模块
  describe '#restore!' do
    let(:deleted_obj) do
      obj.soft_delete(user_id: 1234)
      obj
    end

    # 验证场景：使用严格模式 restore! 进行恢复
    # 核心功能点：底层调用的持久化方法必须是 save!
    # 预期结果：其他字段设置与 restore 一致，但持久化调用变为 save!
    it 'call with correct arguments' do
      deleted_obj.restore!
      expect(deleted_obj.deleted_arguments).to be_an_instance_of(::Hash)
      expect(deleted_obj.deleted_arguments[:method]).to eq(:save!)
      expect(deleted_obj.deleted_arguments[:arguments]).to eq([{ touch: nil }])
      expect(deleted_obj.deleted_at).to be_nil
      expect(deleted_obj.deleted_by).to be_nil
      expect(deleted_obj.deleted).to eq(0)
    end
  end
end
