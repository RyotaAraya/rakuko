# frozen_string_literal: true

module Types
  # 時刻専用の型（タイムゾーン変換なし）
  # PostgreSQLのtime型に対応し、HH:MM:SS形式で保存・読み込みを行う
  class TimeOnly < ActiveRecord::Type::Value
    include ActiveModel::Type::Helpers::Timezone

    def type
      :time
    end

    def cast(value)
      return nil if value.blank?

      # 文字列の場合、HH:MM:SS形式をTimeオブジェクトに変換
      if value.is_a?(String) && value.match?(/^\d{1,2}:\d{2}(:\d{2})?$/)
        parts = value.split(':').map(&:to_i)
        hour = parts[0]
        minute = parts[1]
        second = parts[2] || 0
        # UTCで固定してタイムゾーン変換を避ける
        Time.utc(2000, 1, 1, hour, minute, second)
      elsif value.respond_to?(:hour) && value.respond_to?(:min) && value.respond_to?(:sec)
        # すでにTimeオブジェクトの場合は、時刻部分のみを抽出してUTCで再構築
        Time.utc(2000, 1, 1, value.hour, value.min, value.sec)
      else
        value
      end
    end

    def serialize(value)
      return nil if value.blank?

      # Timeオブジェクトを HH:MM:SS 形式の文字列に変換（データベース保存用）
      if value.respond_to?(:hour)
        format('%02d:%02d:%02d', value.hour, value.min, value.sec)
      elsif value.is_a?(String)
        # すでに文字列の場合はそのまま返す
        value
      else
        nil
      end
    end

    def deserialize(value)
      return nil if value.blank?

      # データベースから読み込んだ値（文字列）をcastで変換
      cast(value)
    end
  end
end
