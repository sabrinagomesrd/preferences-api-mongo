# frozen_string_literal: true

# Padrão reutilizado da Objects API: multi-tenancy via header Platform-Account-Id.
# Preferências estende o modelo com usuário/equipe no body (scope + scope_ref).
class ApplicationController < ActionController::API
  before_action :set_platform_account_id

  protected

  attr_reader :current_platform_account_id

  def render_errors(errors, status:)
    render json: { errors: Array(errors) }, status: status
  end

  def render_validation_errors(record)
    render_errors(
      record.errors.full_messages.map do |message|
        {
          title: "Unprocessable Entity",
          detail: message,
          source: { pointer: "/data" }
        }
      end,
      status: :unprocessable_entity
    )
  end

  private

  def set_platform_account_id
    @current_platform_account_id = Integer(request.headers["Platform-Account-Id"].to_s, 10)
  rescue ArgumentError
    render_errors(
      {
        title: "Bad Request",
        detail: "Invalid platform account ID",
        source: { header: "Platform-Account-Id" }
      },
      status: :bad_request
    )
  end
end
