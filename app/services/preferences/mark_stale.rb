# frozen_string_literal: true

module Preferences
  # Marca registros cujos deltas referenciam campos ausentes em `available_refs`.
  # Dia zero: detecção na leitura — sem mensageria (Pub/Sub N/A).
  class MarkStale
    def self.call(preferences:, available_refs:)
      new(preferences: preferences, available_refs: available_refs).call
    end

    def initialize(preferences:, available_refs:)
      @preferences = Array(preferences)
      @available = Array(available_refs).map(&:to_s)
    end

    def call
      @preferences.each do |preference|
        refs = referenced_fields(preference.payload)
        orphan = refs.any? { |ref| !@available.include?(ref) }
        next if preference.stale == orphan

        preference.update!(stale: orphan)
      end
    end

    private

    def referenced_fields(payload)
      fields = payload.is_a?(Hash) ? (payload["fields"] || payload[:fields] || {}) : {}
      Array(fields["removed"] || fields[:removed]) +
        Array(fields["added"] || fields[:added]) +
        Array(fields["order"] || fields[:order])
    end
  end
end
