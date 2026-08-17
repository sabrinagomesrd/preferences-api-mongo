# frozen_string_literal: true

module V1
  module Preferences
    # Compõe base system + deltas account/team/user.
    #
    # Na arquitetura alvo, a base viria da Apresentação. Nesta POC o cliente
    # envia `base.fields` no body (ou query) para exercitar a mecânica de delta.
    class ResolvedController < ApplicationController
      def show
        base_fields = extract_base_fields
        records = load_layers

        available_refs = Array(params[:available_refs]).presence ||
                         (base_fields + %w[dono data_prevista_fechamento])

        ::Preferences::MarkStale.call(
          preferences: records,
          available_refs: available_refs
        )

        layers = records.map do |record|
          {
            scope: record.scope,
            scope_ref: record.scope_ref,
            payload: record.payload.deep_symbolize_keys
          }
        end

        result = ::Preferences::FieldsResolver.call(base_fields: base_fields, layers: layers)

        render json: {
          data: {
            resource: {
              origin: params.require(:resource_origin),
              key: params.require(:resource_key)
            },
            surface: params.require(:surface),
            type: params.require(:type),
            fields: result.fields,
            layers_applied: result.layers_applied,
            stale_scope_refs: result.stale_scope_refs
          },
          meta: {
            composition: "system(base) → account → team → user",
            base_fields: base_fields,
            raw_layers: records.map(&:as_api_json)
          }
        }
      end

      private

      def extract_base_fields
        from_params = params.dig(:base, :fields) || params[:base_fields]
        return Array(from_params).map(&:to_s) if from_params.present?

        # Fallback didático: base mínima da jornada da Rosana (anexo).
        %w[titulo valor etapa]
      end

      def load_layers
        scope = Preference.for_account(current_platform_account_id).singletons.where(
          resource_origin: params.require(:resource_origin),
          resource_key: params.require(:resource_key),
          surface: params.require(:surface),
          preference_type: params.require(:type)
        )

        refs = [params[:account_ref], params[:team_ref], params[:user_ref]].compact.map(&:to_s)
        scope = scope.in(scope_ref: refs) if refs.any?

        scope.to_a
      end
    end
  end
end
