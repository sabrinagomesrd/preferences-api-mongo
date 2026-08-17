# frozen_string_literal: true

# Preferência humana persistida como *delta* (desvio) — espelho Mongoid da PoC AR.
#
# Escopos graváveis: account | team | user
# Context opcional usa sentinel "" (não null) para o unique parcial não colidir no Mongo.
class Preference
  include Mongoid::Document
  include Mongoid::Timestamps

  RESOURCE_ORIGINS = %w[platform_object product_entity].freeze
  SCOPES = %w[account team user].freeze
  CARDINALITIES = %w[singleton multi].freeze
  SURFACES = %w[
    cartao
    cartao_associado
    arranjo_perfil
    arranjo_painel
    config_formulario
    listagem
  ].freeze
  CONTEXT_SENTINEL = ""

  field :uuid, type: String
  field :platform_account_id, type: Integer
  field :resource_origin, type: String
  field :resource_key, type: String
  field :surface, type: String
  field :preference_type, type: String
  field :context_host, type: String, default: CONTEXT_SENTINEL
  field :context_association, type: String, default: CONTEXT_SENTINEL
  field :scope, type: String
  field :scope_ref, type: String
  field :cardinality, type: String, default: "singleton"
  field :name, type: String
  field :is_default, type: Mongoid::Boolean, default: false
  field :payload, type: Hash, default: -> { {} }
  field :stale, type: Mongoid::Boolean, default: false
  field :created_by, type: String

  index({ uuid: 1 }, { unique: true, name: "uniq_uuid" })

  index(
    {
      platform_account_id: 1,
      resource_origin: 1,
      resource_key: 1,
      surface: 1,
      preference_type: 1,
      context_host: 1,
      context_association: 1,
      scope: 1,
      scope_ref: 1
    },
    {
      unique: true,
      name: "uniq_singleton_identity",
      partial_filter_expression: { cardinality: { "$eq" => "singleton" } }
    }
  )

  index(
    {
      platform_account_id: 1,
      resource_key: 1,
      surface: 1,
      scope: 1,
      scope_ref: 1
    },
    { name: "idx_lookup" }
  )

  validates :uuid, presence: true, uniqueness: true
  validates :platform_account_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :resource_origin, inclusion: { in: RESOURCE_ORIGINS }
  validates :resource_key, :surface, :preference_type, :scope, :scope_ref, :cardinality, presence: true
  validates :scope, inclusion: { in: SCOPES }
  validates :cardinality, inclusion: { in: CARDINALITIES }
  validates :surface, inclusion: { in: SURFACES }
  validates :name, presence: true, if: -> { cardinality == "multi" }
  validate :system_scope_not_allowed

  before_validation :ensure_uuid
  before_validation :normalize_context_sentinels

  scope :for_account, ->(platform_account_id) { where(platform_account_id: platform_account_id) }
  scope :singletons, -> { where(cardinality: "singleton") }
  scope :multi, -> { where(cardinality: "multi") }

  def identity_attributes
    {
      platform_account_id: platform_account_id,
      resource_origin: resource_origin,
      resource_key: resource_key,
      surface: surface,
      preference_type: preference_type,
      context_host: context_host.presence || CONTEXT_SENTINEL,
      context_association: context_association.presence || CONTEXT_SENTINEL,
      scope: scope,
      scope_ref: scope_ref
    }
  end

  def as_api_json
    {
      id: uuid,
      resource: {
        origin: resource_origin,
        key: resource_key
      },
      surface: surface,
      type: preference_type,
      context: context_payload,
      scope: scope,
      scope_ref: scope_ref,
      cardinality: cardinality,
      name: name,
      is_default: is_default,
      payload: payload,
      stale: stale,
      created_by: created_by,
      updated_at: updated_at&.iso8601
    }.compact
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def normalize_context_sentinels
    self.context_host = CONTEXT_SENTINEL if context_host.nil?
    self.context_association = CONTEXT_SENTINEL if context_association.nil?
  end

  def context_payload
    return nil if context_host.blank? && context_association.blank?

    {
      host: context_host,
      association: context_association
    }.compact
  end

  def system_scope_not_allowed
    return unless scope == "system"

    errors.add(:scope, "system is owned by Presentation metadata, not Preferences")
  end
end
