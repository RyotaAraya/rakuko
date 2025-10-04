# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :notification_type
      t.string :title
      t.text :message
      t.datetime :read_at
      t.string :action_url
      t.integer :priority

      t.timestamps
    end
  end
end
