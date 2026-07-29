# 💎 Activemodel::Object::Info

🌍 [English](README.md) | 🇨🇳 [中文文档](README.zh-CN.md) | 🇯🇵 [日本語](README.ja.md)

**Activemodel::Object::Info** は `ActiveModel` と `ActiveRecord` を拡張するための Ruby Gem です。API データ出力のフォーマット、データベースマイグレーション時の監査追跡（Audit Trails）フィールドの生成、および論理削除（Soft Delete）機能などの一般的なビジネス要件に対応するための、エレガントで標準化されたソリューションを提供します。

## 📖 目次

- [✨ 主な機能](#-主な機能)
- [🎯 適用シナリオ](#-適用シナリオ)
- [🚀 インストール](#-インストール)
- [🛠 使い方](#-使い方)
  - [1. 📊 データフォーマット出力 (Base)](#1--データフォーマット出力-base)
  - [2. 🏗 マイグレーションマクロ (TableDefinition)](#2--マイグレーションマクロ-tabledefinition)
  - [3. 🗑 論理削除メカニズム (DeletedOperation)](#3--論理削除メカニズム-deletedoperation)
- [👨‍💻 開発とテスト](#-開発とテスト)
- [📄 ライセンス](#-ライセンス)

## ✨ 主な機能

1. **モデルデータフォーマット (`Base`)**: `ActiveRecord` インスタンスを安全かつ柔軟に Hash（JSON出力用）に変換します。フィールドのホワイトリスト、ブラックリスト、エイリアス、カスタム変換ロジック、および日付のフォーマットをサポートします。
2. **データベースマイグレーションマクロ (`TableDefinition`)**: データベースのテーブルを作成する際、一般的な監査フィールド（例：`created_by`, `updated_by`, `deleted_by`）およびそれに対応するタイムスタンプをワンクリックで生成します。
3. **論理削除メカニズム (`DeletedOperation`)**: 整数型のフラグフィールドに基づく標準的な論理削除を実装し、削除されたデータを隠す `default_scope` を自動で注入します。さらに、削除時の操作者と時間を強制的に記録します。

## 🎯 適用シナリオ

- **RESTful API 開発**: ActiveRecord モデルを JSON レスポンスにシリアライズし、機密データをフィルタリングするための統一された高度に設定可能な方法が必要な場合。
- **エンタープライズ / B2B システム**: ビジネス上、データの監査追跡（Audit Trails）要件が非常に厳しく、誰がいつデータを作成、更新、削除したかを正確に記録する必要がある場合。
- **データ保持要件が厳しいシステム**: データベース内での物理削除（Destroy）が固く禁じられており、すべての削除操作を論理削除（Soft Delete）で行う必要がある場合。

## 🚀 インストール

プロジェクトの Gemfile に以下のコードを追加します：

```ruby
gem 'activemodel-object-info', '~> 0.4.2'
```

その後、依存関係をインストールします：

```bash
$ bundle install
```

## 🛠 使い方

### 1. 📊 データフォーマット出力 (Base)

`ActivemodelObjectInfo::Base` モジュールはモデルに `instance_info` メソッドを注入します。これにより、クラスで定義された定数や実行時に渡されるパラメータに基づいて、インスタンスオブジェクトをフォーマットされた Hash として出力できます。

**モデルでの設定:**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::Base

  # デフォルトの出力設定
  INSTANCE_INFO = {
    only: [:id, :name, :status, :created_at],
    attributes: [
      :id,
      { name: :name, as: :user_name }, # as を使用してエイリアスを設定
      { name: :status, filter: ->(v) { v == 1 ? 'アクティブ' : '非アクティブ' } }, # lambda を使用したカスタム変換ロジック
      { name: :created_at, format: :date }, # 日付をフォーマット ('%Y-%m-%d')
      { name: :virtual_field, type: :abstract, filter: ->(*) { "#{id}-#{name}" } } # 他のフィールドから合成される仮想フィールド
    ]
  }.freeze
  
  # コンテキスト固有の出力設定（名前は INSTANCE_INFO_コンテキスト名 である必要があります）
  INSTANCE_INFO_DETAIL = {
    only: [:id, :name, :email, :phone]
  }.freeze
end
```

**実行時の呼び出し:**

```ruby
user = User.first

# 1. パラメータを渡さない場合、デフォルトでモデルの INSTANCE_INFO 定数設定を使用します
user.instance_info 
# => { id: 1, user_name: "John", status: "アクティブ", created_at: "2026-07-28", virtual_field: "1-John" }

# 2. コンテキストによる出力：context パラメータを指定すると、対応する INSTANCE_INFO_DETAIL 定数を自動的に読み込みます
user.instance_info(context: :detail)
# => { id: 1, name: "John", email: "a@b.com", phone: "12345" }

# 3. 実行時の設定の上書き（Ruby 2.x の Hash と Ruby 3.x のキーワード引数を完全にサポート）
user.instance_info(only: [:id, :name])
# => { id: 1, name: "John" }

# 4. 特定のフィールドの除外 (except)
# デフォルトでは、instance_info は deleted, deleted_by, deleted_at フィールドを自動的に除外します。
# except 配列を渡すことで、デフォルトの動作を上書きし、不要なフィールドを除外できます：
user.instance_info(except: [:status, :created_at])
# => { id: 1, user_name: "John", virtual_field: "1-John" }

# 5. 関連オブジェクトのネスト出力 (includes)
user.instance_info(
  only: [:id, :name],
  includes: {
    profile: { only: [:avatar_url, :bio] },     # has_one / belongs_to の単一インスタンス
    roles: { only: [:role_name] }               # has_many のコレクションインスタンス
  }
)
# => { 
#      id: 1, name: "John", 
#      profile: { avatar_url: "...", bio: "..." }, 
#      roles: [{ role_name: "admin" }, { role_name: "editor" }] 
#    }
```

**日付・時刻のフォーマット (`format`)：**
`Date`, `Time`, `DateTime` 型のフィールドに対して、複数のフォーマット戦略をサポートしています：
- `format: :standard`：ネイティブオブジェクトを維持し、文字列に変換しません
- `format: :full` / `:min` / `:date` / `:month` / `:year`：組み込みのショートカットフォーマットを使用します（例：`:date` は `%Y-%m-%d` を出力します）
- `format: '%Y/%m/%d'`：ネイティブの strftime 文字列を使用します
- `format: ->(v) { "#{v.year}年#{v.month}月#{v.day}日" }`：`Proc` / `Lambda` を渡して完全にカスタムなフォーマットを実現します（`0.4.2` 以降でサポート）

*グローバルな日付フォーマット*: `attributes` 配列内で個々のフィールドに対して `format` を指定するだけでなく、`datetime_format` パラメータを渡すことでグローバルなデフォルトを設定できます：
```ruby
user.instance_info(datetime_format: :date) # すべての時刻フィールドはデフォルトで :date フォーマットを使用します
```

### 2. 🏗 マイグレーションマクロ (TableDefinition)

`ActivemodelObjectInfo::TableDefinition` モジュールは ActiveRecord の Migration を拡張し、監査フィールドを簡単に生成できるようにします。

**マイグレーションファイルでの使用:**

```ruby
class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :name
      
      # 1. ライフサイクル監査フィールドのフルセットを生成：
      # t.generate_operations を引数なしで呼び出すと、デフォルトで created, updated, deleted フィールドが生成されます。
      # 生成されるフィールド: created_by, created_at, updated_by, updated_at, deleted(int), deleted_by, deleted_at
      # 注意：生成されるタイムスタンプと操作者フィールドには、デフォルトでデータベースインデックスが付与されます (index: true)。
      t.generate_operations
      
      # 2. または、特定のカスタム監査フィールドを生成：
      # t.operation_columns は :audit に対応する操作者(bigint)と操作時間(datetime)を生成します。
      # 生成されるフィールド: audit_by (bigint), audit_at (datetime)
      t.operation_columns(:audit)
      
      # 3. プレフィックス、サフィックス、およびフィールド生成の高度なカスタマイズ：
      # 生成されるフィールド: my_review_user (bigint), my_review_time (datetime)
      # with_operator / with_timestamp を使用して、操作者またはタイムスタンプフィールドを個別に生成するかどうかを制御できます。
      t.operation_columns(:review, operator_prefix: 'my_', operator_suffix: '_user', timestamp_suffix: '_time', with_operator: true, with_timestamp: true)
    end
  end
end
```

### 3. 🗑 論理削除メカニズム (DeletedOperation)

`ActivemodelObjectInfo::DeletedOperation` モジュールは、`TableDefinition` マクロで生成された基盤となるフィールドと完全に連携する、すぐに使える論理削除機能を提供します。

**モデルでの設定:**

```ruby
class User < ApplicationRecord
  include ActivemodelObjectInfo::DeletedOperation
  
  # オプション: レガシーデータベースで異なる命名規則を使用している場合は、以下の定数を上書きできます
  # DELETED_FIELD = 'is_deleted'
  # DELETED_VALID_VALUE = false
  # DELETED_INVALID_VALUE = true
end
```

**実行時の呼び出し:**

```ruby
# 1. 自動クエリスコープ:
# このモジュールをインクルードすると、削除されたレコードを隠す `default_scope` が自動的に注入されます。
User.all # 実際に実行されるSQL => SELECT * FROM users WHERE deleted = 0

# 2. 論理削除の実行:
user = User.find(1)

# セキュリティと監査の規範により、削除操作を実行するユーザーの ID (user_id) を【必ず】提供する必要があります
user.soft_delete(user_id: current_user.id)
# これにより自動的に以下の操作が実行されます：
# - `deleted` フラグを 1 に設定
# - `deleted_by` を current_user.id に設定
# - `deleted_at` を現在時刻 Time.now に設定
# - `save` を呼び出してデータベースに保存

# 3. 論理削除と同時に更新時間 (updated_at) をリフレッシュ:
user.soft_delete(user_id: current_user.id, refresh_updated: true)

# 4. 厳密な論理削除 (内部で save! を呼び出し、失敗時に例外をスロー):
user.soft_delete!(user_id: current_user.id)

# 5. 論理削除されたデータの復元 (論理削除の取り消し):
# 注意：論理削除されたデータは default_scope によってフィルタリングされるため、unscoped を使用して検索する必要があります
deleted_user = User.unscoped.find(1)

# 復元操作の実行。これにより deleted フラグが 0 にリセットされ、deleted_by と deleted_at がクリアされます
deleted_user.restore

# 6. 復元と同時に更新者と更新時間を記録:
deleted_user.restore(user_id: current_user.id, refresh_updated: true)

# 7. 厳密な復元 (内部で save! を呼び出し、失敗時に例外をスロー):
deleted_user.restore!(user_id: current_user.id)
```

## 👨‍💻 開発とテスト

リポジトリをクローンした後、`bin/setup` を実行して開発用の依存関係をインストールします。

RSpec ユニットテストを実行する：
```bash
$ bundle exec rspec
```

RuboCop コードスタイル静的チェックを実行する：
```bash
$ bundle exec rubocop
```

## 📄 ライセンス

このプロジェクトは [MIT License](https://opensource.org/licenses/MIT) の下でオープンソースとして利用可能です。