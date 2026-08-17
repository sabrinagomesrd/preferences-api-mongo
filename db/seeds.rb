# frozen_string_literal: true

# Jornada da Rosana — seed Mongoid (sem db:migrate).
account_id = 42

Preference.where(platform_account_id: account_id).delete_all

Preference.create!(
  platform_account_id: account_id,
  resource_origin: "platform_object",
  resource_key: "deal",
  surface: "cartao",
  preference_type: "cartao_fields",
  scope: "team",
  scope_ref: "time_negociadores",
  cardinality: "singleton",
  payload: {
    "fields" => {
      "removed" => ["etapa"],
      "added" => ["dono"]
    }
  },
  created_by: "seed:team"
)

Preference.create!(
  platform_account_id: account_id,
  resource_origin: "platform_object",
  resource_key: "deal",
  surface: "cartao",
  preference_type: "cartao_fields",
  scope: "user",
  scope_ref: "rosana",
  cardinality: "singleton",
  payload: {
    "fields" => {
      "added" => ["data_prevista_fechamento"]
    }
  },
  created_by: "seed:user"
)

Preference.create!(
  platform_account_id: account_id,
  resource_origin: "platform_object",
  resource_key: "contact",
  surface: "listagem",
  preference_type: "saved_filter",
  scope: "user",
  scope_ref: "rosana",
  cardinality: "multi",
  name: "Meus quentes",
  is_default: true,
  payload: {
    "filters" => [
      { "field" => "lifecycle_stage", "op" => "eq", "value" => "opportunity" }
    ]
  },
  created_by: "seed:user"
)

puts "Seeded preferences (mongo) for platform_account_id=#{account_id}"
