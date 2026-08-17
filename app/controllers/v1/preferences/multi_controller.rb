# frozen_string_literal: true

module V1
  module Preferences
    class MultiController < ApplicationController
      def index
        records = Preference.for_account(current_platform_account_id).multi.where(filter_params)
        render json: { data: records.map(&:as_api_json) }
      end

      def create
        record = Preference.new(multi_attributes.merge(
          platform_account_id: current_platform_account_id,
          cardinality: "multi"
        ))

        if record.save
          render json: { data: record.as_api_json }, status: :created
        else
          render_validation_errors(record)
        end
      end

      def destroy
        record = Preference.for_account(current_platform_account_id).multi.where(uuid: params[:id]).first
        return render_not_found unless record

        record.destroy!
        head :no_content
      end

      private

      def filter_params
        {
          resource_origin: params.require(:resource_origin),
          resource_key: params.require(:resource_key),
          surface: params.require(:surface),
          preference_type: params.require(:type),
          scope: params[:scope],
          scope_ref: params[:scope_ref]
        }.compact
      end

      def multi_attributes
        {
          resource_origin: params.require(:resource).require(:origin),
          resource_key: params.require(:resource).require(:key),
          surface: params.require(:surface),
          preference_type: params.require(:type),
          context_host: params.dig(:context, :host).presence || Preference::CONTEXT_SENTINEL,
          context_association: params.dig(:context, :association).presence || Preference::CONTEXT_SENTINEL,
          scope: params.require(:scope),
          scope_ref: params.require(:scope_ref).to_s,
          name: params.require(:name),
          is_default: ActiveModel::Type::Boolean.new.cast(params.fetch(:is_default, false)),
          payload: params.require(:payload).permit!.to_h,
          created_by: params[:created_by]
        }
      end

      def render_not_found
        render_errors(
          { title: "Not Found", detail: "Preference not found" },
          status: :not_found
        )
      end
    end
  end
end
