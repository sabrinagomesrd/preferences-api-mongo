# frozen_string_literal: true

module Preferences
  # Resolve campos de cartão/listagem aplicando deltas em cascata.
  #
  # Ordem (Visão §4.3): system → account → team → user
  # - `system` chega como *base* (lista absoluta) — não é persistida aqui
  # - demais camadas trazem só desvios: removed / added / order opcional
  #
  # Delta órfão: referência que sumiu da base resultante → ignorada na leitura;
  # o chamador pode marcar o registro como stale.
  class FieldsResolver
    LAYER_ORDER = %w[account team user].freeze

    Result = Struct.new(:fields, :stale_scope_refs, :layers_applied, keyword_init: true)

    def self.call(base_fields:, layers:)
      new(base_fields: base_fields, layers: layers).call
    end

    def initialize(base_fields:, layers:)
      @fields = Array(base_fields).map(&:to_s)
      @layers = Array(layers)
      @stale_scope_refs = []
      @layers_applied = []
    end

    def call
      LAYER_ORDER.each do |scope|
        layer = @layers.find { |item| item[:scope].to_s == scope }
        next unless layer

        apply_delta(layer)
        @layers_applied << scope
      end

      Result.new(
        fields: @fields,
        stale_scope_refs: @stale_scope_refs.uniq,
        layers_applied: @layers_applied
      )
    end

    private

    def apply_delta(layer)
      delta = layer.dig(:payload, :fields) || layer.dig(:payload, "fields") || {}
      removed = Array(delta[:removed] || delta["removed"]).map(&:to_s)
      added = Array(delta[:added] || delta["added"]).map(&:to_s)
      order = delta[:order] || delta["order"]

      removed.each do |field|
        unless @fields.include?(field)
          @stale_scope_refs << layer[:scope_ref].to_s
          next
        end

        @fields.delete(field)
      end

      added.each do |field|
        # POC: added só entra se ainda não estiver na lista resultante.
        # (A divergência "precedência restritiva" vs "add de campos do schema"
        # permanece em aberto na Visão — aqui preferimos o exemplo da Rosana.)
        @fields << field unless @fields.include?(field)
      end

      return if order.blank?

      ordered = Array(order).map(&:to_s)
      known = ordered.select { |field| @fields.include?(field) }
      leftovers = @fields - known
      @fields = known + leftovers
    end
  end
end
