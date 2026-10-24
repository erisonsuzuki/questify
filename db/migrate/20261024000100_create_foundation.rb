class CreateFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :kind, null: false
      t.datetime :last_online_at, null: false
      t.timestamps
    end
    add_check_constraint :users, "kind IN ('guest', 'account')", name: "users_kind"

    create_table :accounts, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :email, null: false
      t.string :password_digest, null: false
      t.datetime :verified_at
      t.timestamps
    end
    add_index :accounts, :email, unique: true

    create_table :access_sessions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.datetime :last_seen_at, null: false
      t.datetime :absolute_expires_at, null: false
      t.datetime :authenticated_at
      t.datetime :revoked_at
      t.timestamps
    end

    create_table :credential_tokens, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :digest, null: false
      t.text :delivery_payload
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :credential_tokens, :digest, unique: true
    add_check_constraint :credential_tokens, "purpose IN ('verify', 'reset')", name: "credential_tokens_purpose"

    create_table :registrations, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.references :source_user, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :login_buckets, id: :uuid do |t|
      t.string :key, null: false
      t.jsonb :failures, null: false, default: []
      t.timestamps
    end
    add_index :login_buckets, :key, unique: true
  end
end
