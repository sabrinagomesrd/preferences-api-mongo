# frozen_string_literal: true

module V1
  module Preferences
    class RawController < ApplicationController
      SCOPE_ORDER = { "account" => 1, "team" => 2, "user" => 3 }.freeze

      def show
        records = Preference.for_account(current_platform_account_id)
          .singletons
          .where(
            resource_origin: params.require(:resource_origin),
            resource_key: params.require(:resource_key),
            surface: params.require(:surface),
            preference_type: params.require(:type)
          )
          .to_a
          .sort_by { |r| SCOPE_ORDER.fetch(r.scope, 99) }

        if params[:context_host].present?
          records = records.select { |r| r.context_host == params[:context_host] }
        end

        render json: {
          data: records.map(&:as_api_json),
          meta: {
            note: "system layer is not stored here; provide it to /resolved as base",
            store: "mongoid"
          }
        }
      end
    end
  end
end
