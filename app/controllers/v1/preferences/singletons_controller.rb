# frozen_string_literal: true

module V1
  module Preferences
    class SingletonsController < ApplicationController
      def upsert
        record = find_singleton
        created = record.nil?
        record ||= Preference.new(cardinality: "singleton")
        record.assign_attributes(singleton_attributes)
        record.platform_account_id = current_platform_account_id

        if record.save
          render json: { data: record.as_api_json }, status: created ? :created : :ok
        else
          render_validation_errors(record)
        end
      end

      def destroy
        record = find_singleton
        return render_not_found unless record

        record.destroy!
        head :no_content
      end

      private

      def find_singleton
        Preference.for_account(current_platform_account_id).singletons.where(identity_from_params).first
      end

      def identity_from_params
        {
          resource_origin: params.require(:resource).require(:origin),
          resource_key: params.require(:resource).require(:key),
          surface: params.require(:surface),
          preference_type: params.require(:type),
          context_host: params.dig(:context, :host).presence || Preference::CONTEXT_SENTINEL,
          context_association: params.dig(:context, :association).presence || Preference::CONTEXT_SENTINEL,
          scope: params.require(:scope),
          scope_ref: params.require(:scope_ref).to_s
        }
      end

      def singleton_attributes
        identity_from_params.merge(
          payload: params.require(:payload).permit!.to_h,
          created_by: params[:created_by],
          stale: false
        )
      end

      def render_not_found
        render_errors(
          {
            title: "Not Found",
            detail: "Singleton preference not found for this identity"
          },
          status: :not_found
        )
      end
    end
  end
end
