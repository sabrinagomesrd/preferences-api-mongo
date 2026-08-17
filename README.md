# preferences-api-mongo (POC)

POC irmã da `preferences-api` — **mesmo contrato HTTP e domínio**, store = **MongoDB via Mongoid**.

> **Não é** serviço de produção. **Não fecha** ADR de persistência.

## Como o ActiveRecord saiu e o Mongoid entrou

Não basta um arquivo: o desvio é um conjunto.

| Camada                  | O que mudou                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `Gemfile`               | `gem "mongoid"`; **sem** `sqlite3` / `pg` / `solid_cache` / `solid_queue`                             |
| `config/application.rb` | **Não** carrega `active_record/railtie` (só Active Model, Active Job, Action Controller, Action View) |
| `config/mongoid.yml`    | URI do Mongo (`MONGO_URI` ou default local)                                                           |
| Model                   | `Preference` inclui `Mongoid::Document` + `field` / `index` (não herda `ApplicationRecord`)           |
| Ausências               | sem `database.yml`, sem `db/migrate`, sem `ApplicationRecord`                                         |
| Índices                 | `bin/rails db:create_indexes` (`lib/tasks/mongo.rake`) — **não** `db:migrate`                         |

`mongoid.yml` configura _como_ conectar. O app usa Mongo porque a gem está no bundle, o railtie do ActiveRecord está fora e o model é `Mongoid::Document`.

Os `field :...` no model são o mapa Mongoid (tipos/defaults) — o Mongo em si continua sem schema rígido; isso é o contrato do app com o documento.

### `_id` vs `uuid`

|            | `_id`          | `uuid`                                            |
| ---------- | -------------- | ------------------------------------------------- |
| Quem cria  | Mongo (sempre) | App (`ensure_uuid`)                               |
| Formato    | `ObjectId`     | UUID string                                       |
| Uso na API | interno        | exposto como `id` em `as_api_json` / DELETE multi |

## Decisões deste incremento

| Decisão                    | Escolha                                                                                        | Por quê                                                                                                                                                                                                                                                                                              |
| -------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ODM                        | **Mongoid ~> 9** (não driver cru)                                                              | Padrão Rails na RD (CRM usa Mongoid); model + índices declarativos                                                                                                                                                                                                                                   |
| ActiveRecord               | **Removido** deste app                                                                         | Preferências no dia zero é Mongoid-only: o domínio não usa SQL, e manter ActiveRecord só puxaria `solid_cache`/`solid_queue` (sem requisito). Esta PoC valida o desvio do template Rails sem ActiveRecord.                                                                                           |
| Schema de identity         | Campos **flat**                                                                                | Mesmos atributos de identidade no documento (`platform_account_id`, `resource_*`, `surface`, `scope`…) em vez de aninhar `resource`/`context` como subdocumentos — facilita comparar com o Esboço A (relacional) e com a PoC ActiveRecord; aninhar seria só organização do JSON, sem ganho de regra. |
| Context vazio              | Sentinel `""` (não `null`/ausente)                                                             | `context` é opcional no contrato mas entra na identidade; sentinel normaliza a chave nos dois stores                                                                                                                                                                                                 |
| Unique singleton           | Índice unique + `partial_filter_expression: cardinality == singleton`                          | Espelho do unique parcial PG; CRM **não** usa partial (só unique/sparse)                                                                                                                                                                                                                             |
| Query `scope_ref IN (...)` | Mongoid: `.in(scope_ref: refs)` — `where(scope_ref: array)` **não** basta como no ActiveRecord | Lição do smoke `/resolved`                                                                                                                                                                                                                                                                           |

## O que foi criar / alterar / apagar

### Criar

- `Gemfile` com `mongoid` (sem `sqlite3` / `solid_cache` / `solid_queue`)
- `config/mongoid.yml`, `docker-compose.yml`
- `app/models/preference.rb` (Mongoid::Document + índices)
- `lib/tasks/mongo.rake` (`db:create_indexes`)
- Este README

### Alterar

- `config/application.rb` — sem `active_record/railtie`; módulo `PreferencesApiMongo`
- Controllers singleton/multi/raw — APIs Mongoid (`where.first`, ordenação em Ruby)
- `health` — `service: preferences-api-mongo`, `store: mongoid`
- Environments — removidas configs ActiveRecord / `solid_cache` / `solid_queue`
- Seeds — mesmos dados Rosana; `context_*` caem no sentinel

### Apagar (deste app)

- `config/database.yml`, `db/migrate/*`, `app/models/application_record.rb`
- Dependência de SQLite / gems `solid_cache` e `solid_queue` (cache e fila do template Rails 8 via ActiveRecord — não usáveis com Mongoid-only)

## Subir local

Pré-requisitos: Docker, Ruby alinhado a `.ruby-version`, Bundler.

```bash
cd ~/Developer/rd-station/preferences-api-mongo
docker compose up -d
bundle config set --local path 'vendor/bundle'
bundle install
bin/rails db:create_indexes
bin/rails runner db/seeds.rb
bin/rails server -p 3002
```

Em outro terminal (smoke de leitura):

```bash
BASE_URL=http://localhost:3002 bin/demo
```

- URI default: `mongodb://127.0.0.1:27017/preferences_api_mongo_development`

O seed grava a jornada da Rosana (conta `42`: singleton team/user no cartão de deal + filtro multi na listagem de contact). Rodar de novo **apaga** as preferences dessa conta e recria.

## Ver no MongoDB Compass

1. Subir o compose (`docker compose up -d`) se ainda não estiver no ar.
2. Nova conexão: `mongodb://127.0.0.1:27017`.
3. Collection: **`preferences`**

O que aparece além disso:

- `admin`, `config`, `local` — databases **de sistema** do Mongo (não criados pelo código da PoC).
- `preferences` — criados na primeira escrita (seed, API ou `create_indexes`).

Cada documento tem `_id` (ObjectId do Mongo) e `uuid` (id de domínio da API). Expanda `payload` no Compass para ver o delta.

## Endpoints

Mesmos da PoC ActiveRecord (`preferences-api`). Header obrigatório: `Platform-Account-Id`.

| Método           | Caminho                     | Uso                         |
| ---------------- | --------------------------- | --------------------------- |
| `GET`            | `/health_check`             | health + `store: mongoid`   |
| `GET`            | `/v1/preferences/raw`       | camadas singleton gravadas  |
| `GET`            | `/v1/preferences/resolved`  | resolve com `base` na query |
| `PUT` / `DELETE` | `/v1/preferences/singleton` | upsert / apaga singleton    |
| `GET` / `POST`   | `/v1/preferences`           | lista / cria multi          |
| `DELETE`         | `/v1/preferences/:id`       | apaga multi por `uuid`      |

### Por que singleton usa `PUT` (e não `POST`) nesta PoC

Singleton = **no máximo um** desvio por identidade (conta + resource + surface + type + context + scope + scope_ref). Escrever de novo **substitui** o mesmo artefato — não cria o segundo.

`PUT /v1/preferences/singleton` é **upsert** por essa identidade: primeira vez cria (201), mesma identidade de novo atualiza o `payload` (200). O verbo idempotente casa com “declarar o estado desejado do desvio”, não com “criar mais um registro”.

`POST /v1/preferences` fica para **multi** (filtros salvos, etc.), em que cada chamada **cria** uma instância nova (`uuid` novo, com `name`).

Espelho da PoC ActiveRecord / padrão `PUT`/`DELETE` de singleton do anexo de Apresentação. **Não** é ADR: o contrato oficial ainda pode escolher outro desenho HTTP; o que o domínio exige é a regra de um-por-identidade + upsert.

## O que este incremento **não** responde

- Cloud SQL vs Atlas em produção
- Custo mensal Mongo managed na org
- Ownership de `/resolved`
- Forma canônica do `payload` por superfície
