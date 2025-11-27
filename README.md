# 内部通信のみのバックエンドにNginxリバースプロキシでアクセスする実践ガイド

## はじめに

このリポジトリは、**バックエンドAPIを内部通信のみに制限しながら、Nginxリバースプロキシを使ってフロントエンドからアクセス可能にする**実践的なサンプルアプリケーションです。

モダンなWebアプリケーション開発において、セキュリティは重要な課題です。特に、**バックエンドAPIを直接インターネットに公開せず、内部通信のみに制限したい**というニーズが増えています。

しかし、単純にバックエンドを内部通信のみにすると、フロントエンドからアクセスできなくなってしまいます。

**そこで、Nginxをリバースプロキシとして配置することで、以下を実現します：**

1. バックエンドは内部通信のみ（外部からの直接アクセス不可）
2. フロントエンドからはNginx経由でアクセス可能
3. CORS問題も同時に解決
4. セキュリティとパフォーマンスの向上

## アーキテクチャ概要

### ローカル開発環境（Docker Compose）

```
┌─────────────────────────────────────────────────────────┐
│                    ブラウザ                              │
│                 http://localhost                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│            Nginx (リバースプロキシ)                      │
│                   Port 80 (外部公開)                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Location /        → Flutter静的ファイル配信    │   │
│  │  Location /api/*   → バックエンドにプロキシ     │   │
│  └─────────────────────────────────────────────────┘   │
│                        ↓ proxy_pass                     │
│                   (内部通信のみ)                        │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  FastAPI Backend     │
              │  Port 8000           │
              │  (内部通信のみ)       │
              │  expose: 8000        │
              └──────────────────────┘
```

**重要：バックエンドは `expose` で内部通信のみに制限され、外部から直接アクセスできません。ただし、Nginx経由では `/api/*` へのリクエストが無条件でプロキシされるため、バックエンド側での認証・認可の実装が必須です。**

### Cloud Run環境

```
┌─────────────────────────────────────────────────────────┐
│                    ブラウザ                              │
│         https://frontend-xxx.run.app                    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│       Frontend Cloud Run Service (外部公開)             │
│            Nginx + Flutter Web                          │
│            ingress: all                                 │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Location /        → Flutter静的ファイル配信    │   │
│  │  Location /api/*   → バックエンドにプロキシ     │   │
│  └─────────────────────────────────────────────────┘   │
│                        ↓ proxy_pass                     │
│                   (内部通信のみ)                        │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Backend Cloud Run   │
              │  Service             │
              │  ingress: internal   │
              │  (内部通信のみ)       │
              └──────────────────────┘
```

**Cloud Runでは、バックエンドの `ingress: internal` 設定により、外部からの直接アクセスを完全にブロックします。ただし、Nginx経由では `/api/*` へのリクエストが無条件でプロキシされるため、バックエンド側での認証・認可とIAM認証の実装が推奨されます。**

## なぜこの構成が必要なのか？

### 1. バックエンドを直接公開から保護（ネットワークレイヤー）

**セキュリティ上の理由から、バックエンドAPIへの直接アクセスを制限したい場合があります：**

- バックエンドのURLやエンドポイント構造を外部に公開したくない
- DDoS攻撃の標的となる表面積を減らす
- 認証が不要なエンドポイント（healthcheckなど）の探索を防ぐ
- 内部サービス間通信として設計されたAPIを保護

**しかし、単純にバックエンドを内部通信のみにすると、フロントエンドからアクセスできません。**

#### 解決策：Nginxリバースプロキシ

Nginxをリバースプロキシとして配置することで：

- **バックエンドは内部通信のみに制限**（Docker Composeの `expose`、Cloud Runの `ingress: internal`）
- **フロントエンドはNginx経由でバックエンドにアクセス可能**
- **外部からはNginxのみが公開され、バックエンドへの直接アクセスをブロック**

> **⚠️ 重要：セキュリティの境界について**
>
> この構成は**ネットワークレイヤーでの保護**であり、アプリケーションレベルのセキュリティではありません。
>
> - Nginxは `/api/*` へのリクエストを**無条件でバックエンドにプロキシ**します
> - つまり、攻撃者が `https://frontend-url/api/admin/delete_user` を叩けば、Nginxはそれをバックエンドに転送します
> - **バックエンド側で適切な認証・認可の実装が必須**です（JWT検証、セッション管理など）
>
> この構成で得られるのは：
> - ✅ バックエンドのURL/エンドポイントの隠蔽（Security by Obscurity）
> - ✅ バックエンドへの直接アクセスの防止
> - ❌ APIレベルのアクセス制御（別途実装が必要）

### 2. CORS問題の根本的解決

通常、フロントエンドとバックエンドが異なるオリジン（プロトコル、ドメイン、ポートのいずれかが異なる）で動作する場合、ブラウザのセキュリティ機能によりCORSエラーが発生します。

```
フロントエンド: http://localhost:3000
バックエンド:   http://localhost:8000
→ 異なるポート = 異なるオリジン = CORSエラー
```

**Nginxをリバースプロキシとして配置すると**：

```
ブラウザ → http://localhost/         (フロントエンド)
ブラウザ → http://localhost/api/*    (バックエンドへプロキシ)
→ 同じオリジン = CORS問題なし
```

ブラウザから見ると、すべてのリクエストが同じオリジン（`http://localhost`）に対して行われるため、**CORS設定が不要になります**。

### 3. 単一エントリーポイント

ユーザーは1つのURLだけを知っていれば良く、フロントエンドとバックエンドの内部構成を意識する必要がありません。

### 4. セキュリティ対策の一元管理

Nginxでセキュリティ対策を一元管理できます：

- レート制限（API呼び出し頻度の制限）
- IP制限（特定IPからのアクセス制御）
- 認証・認可の統一実装
- セキュリティヘッダー（CSP、X-Content-Type-Optionsなど）の設定

### 5. パフォーマンスの最適化

- 静的ファイルのキャッシング
- gzip圧縮の有効化
- コネクションのkeepalive設定
- 負荷分散（複数のバックエンドサーバーがある場合）

### 6. インフラ構成のシンプル化

- Docker Composeで簡単にローカル開発環境を構築
- Cloud Runなどでフロントエンドとバックエンドを別々にスケール
- 環境変数でバックエンドURLを動的に変更可能

## プロジェクト構成

```
reverse-proxy/
├── frontend-proxy/              # Flutter Webアプリケーション
│   ├── lib/
│   │   └── main.dart     # Flutterアプリケーションコード
│   ├── web/              # Webアセット
│   ├── Dockerfile        # マルチステージビルド（Flutter + Nginx）
│   ├── nginx.conf        # Nginx設定ファイル（テンプレート）
│   ├── proxy_params_common  # プロキシ共通設定
│   ├── docker-entrypoint.sh # 起動時設定スクリプト
│   └── pubspec.yaml      # Flutter依存関係
│
├── backend/              # FastAPIアプリケーション
│   ├── main.py           # FastAPIアプリケーションコード
│   ├── requirements.txt  # Python依存関係
│   └── Dockerfile        # Dockerイメージ設定
│
├── terraform/            # Terraformインフラ定義
│   ├── main.tf           # プロバイダー設定、VPCモジュール呼び出し
│   ├── variables.tf      # 変数定義
│   ├── locals.tf         # ローカル変数（イメージURL生成）
│   ├── artifact_registry.tf  # Artifact Registryリポジトリ
│   ├── backend.tf        # バックエンドCloud Runサービス
│   ├── frontend.tf       # フロントエンドCloud Runサービス
│   ├── service_account.tf     # サービスアカウント設定
│   ├── terraform.tfvars.example  # 変数ファイル例
│   ├── modules/
│   │   ├── vpc/          # VPCネットワークモジュール
│   │   └── frontend/     # フロントエンドモジュール
│   └── .gitignore        # Terraform用.gitignore
│
├── deployment/           # デプロイスクリプト
│   ├── setup.sh          # 初期セットアップ（API有効化、Artifact Registry作成）
│   ├── deploy-cloudbuild.sh  # Cloud Build + Terraformデプロイ
│   ├── deploy-terraform.sh   # Terraformのみでデプロイ
│   ├── build-images.sh   # Dockerイメージビルド・プッシュ
│   └── destroy.sh        # リソース削除
│
├── .cloudbuild/          # Cloud Build設定ファイル
│   ├── cloudbuild.yaml   # Cloud Runへ直接デプロイ
│   ├── cloudbuild-deploy.yaml  # Cloud Build + Terraform統合デプロイ
│   ├── backend.yaml      # バックエンド単体デプロイ
│   └── frontend.yaml     # フロントエンド単体デプロイ
│
├── .env.example          # 環境変数設定例
├── .gitignore            # Git除外ファイル
├── .gcloudignore         # Cloud Build除外ファイル
├── compose.yaml          # Docker Compose設定
└── DEPLOYMENT.md         # デプロイガイド
```

## セットアップ＆実行方法

### 前提条件

- Docker & Docker Compose がインストールされていること

### 起動

```bash
# リポジトリをクローン
git clone <repository-url>
cd reverse-proxy

# Docker Composeでビルド＆起動
docker compose up --build
```

### アクセス

ブラウザで `http://localhost` にアクセスしてください。

- フロントエンド（Flutter Web）が表示されます
- 「アイテム一覧を取得」ボタンをクリックすると、`/api/items` にリクエストが送信されます
- Nginxが `/api/*` へのリクエストをバックエンド（FastAPI）にプロキシします

### 内部通信のみであることを確認

バックエンドが本当に内部通信のみになっているか確認してみましょう：

```bash
# ❌ バックエンドに直接アクセスしようとすると失敗する
curl http://localhost:8000/api/items
# → curl: (7) Failed to connect to localhost port 8000: Connection refused

# ✅ Nginx経由でアクセスすると成功する
curl http://localhost/api/items
# → [{"id":1,"name":"Item 1","description":"This is item 1"}...]
```

これにより、バックエンドが外部から直接アクセスできず、Nginxを通してのみアクセス可能であることが確認できます。

## 技術的なポイント解説

### 1. Nginx設定のキーポイント

#### upstream設定

```nginx
upstream backend {
    server backend:8000;
    keepalive 32;
}
```

- バックエンドサーバーをupstreamとして定義
- keepaliveでコネクションを再利用し、パフォーマンス向上

#### location設定

```nginx
# APIリクエストをバックエンドにプロキシ
location /api/ {
    proxy_pass http://backend/api/;
    include /etc/nginx/proxy_params_common;
}

# それ以外はFlutter Webの静的ファイルを配信
location / {
    try_files $uri $uri/ /index.html;
}
```

- `/api/*` へのリクエストはバックエンドに転送
- それ以外は静的ファイルとして配信
- `try_files` でSPAのルーティングに対応

### 2. Docker entrypointの動的設定

`docker-entrypoint.sh` では、環境変数 `BACKEND_URL` から自動的にバックエンドの接続情報を抽出し、Nginx設定ファイルに反映します。

```bash
# BACKEND_URL=http://backend:8000 から
BACKEND_SCHEME=http
BACKEND_HOST=backend
BACKEND_PORT=8000
# を抽出し、nginx.confに置換
```

これにより、環境ごとに異なるバックエンドURLを柔軟に設定できます。

### 3. マルチステージビルド

Dockerfileでは2段階のビルドを行っています：

```dockerfile
# Stage 1: Flutterアプリケーションをビルド
FROM instrumentisto/flutter:3.24 AS builder
WORKDIR /app
COPY . .
RUN flutter build web --release

# Stage 2: Nginxイメージに静的ファイルをコピー
FROM nginx:stable-alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf.template
...
```

- ビルド用のFlutterイメージとランタイム用のNginxイメージを分離
- 最終イメージサイズを削減
- 本番環境に不要なビルドツールを含めない

## 実装のキーポイント

このパターンを実装する際の重要なポイント：

### Docker Composeでの内部通信制限

```yaml
services:
  backend:
    # ❌ 外部に公開する場合
    # ports:
    #   - "8000:8000"

    # ✅ 内部通信のみ（推奨）
    expose:
      - "8000"
```

`expose` を使うことで、コンテナ間の内部通信のみを許可し、外部からの直接アクセスを防ぎます。

### Cloud Runでの内部通信制限

```hcl
resource "google_cloud_run_service" "backend" {
  metadata {
    annotations = {
      # 内部通信のみ許可
      "run.googleapis.com/ingress" = "internal"
    }
  }
}
```

`ingress: internal` により、同じGCPプロジェクト内からのアクセスのみを許可します。

> **⚠️ 重要：Cloud RunのIAM認証について**
>
> **本サンプルでは簡略化のため、バックエンドに `allUsers` の `run.invoker` ロールを付与しています。**
> これは、Internal Ingressの範囲内であれば**誰でも認証なしでアクセス可能**な状態です。
>
> **本番環境では以下の対応が推奨されます：**
>
> 1. **IAM認証の有効化**
>    - バックエンドに `allUsers` を許可せず、特定のサービスアカウントのみに `run.invoker` を付与
>    - NginxからMetadata Serverを使ってID トークンを取得し、`Authorization` ヘッダーに付与
>
> 2. **参考実装**
>    ```bash
>    # Metadata ServerからID トークンを取得
>    TOKEN=$(curl -H "Metadata-Flavor: Google" \
>      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=https://backend-url")
>
>    # NginxでAuthorizationヘッダーに付与（auth_request モジュールなどを使用）
>    proxy_set_header Authorization "Bearer $TOKEN";
>    ```
>
> 3. **トレードオフ**
>    - IAM認証を有効にすると、Nginx側でトークン取得・更新の実装が必要
>    - 本サンプルではアーキテクチャパターンの説明に集中するため、この実装は省略しています
>
> **現状のセキュリティレベル：**
> - ✅ VPC外部からの直接アクセスは完全にブロック
> - ⚠️ 同じVPC内の他のサービス（侵害されたコンテナなど）からはアクセス可能
> - ❌ Service-to-Service認証は未実装（本番環境では実装を強く推奨）

## Cloud Runへのデプロイ

このアプリケーションはGoogle Cloud Runにデプロイできます。詳細な手順は [DEPLOYMENT.md](DEPLOYMENT.md) を参照してください。

### デプロイスクリプトを使用（推奨）

環境変数ファイルを使った簡単なデプロイ:

```bash
# 1. 環境変数を設定
cp .env.example .env
# .envファイルを編集してGCP_PROJECT_IDなどを設定

# 2. 初期セットアップ（初回のみ）
./deployment/setup.sh

# 3. デプロイ
./deployment/deploy-cloudbuild.sh
```

利用可能なスクリプト:
- `setup.sh` - API有効化とArtifact Registry作成
- `deploy-cloudbuild.sh` - Cloud Build + Terraformで自動デプロイ
- `deploy-terraform.sh` - Terraformのみでデプロイ
- `build-images.sh` - Dockerイメージのビルドとプッシュ
- `destroy.sh` - 全リソースの削除

### 手動デプロイ

```bash
# Cloud Build + Terraform統合デプロイ
gcloud builds submit \
  --config=.cloudbuild/cloudbuild-deploy.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

# Cloud Build のみ（Terraformなし）
gcloud builds submit \
  --config=.cloudbuild/cloudbuild.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

# バックエンドまたはフロントエンド単体デプロイ
gcloud builds submit \
  --config=.cloudbuild/backend.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

gcloud builds submit \
  --config=.cloudbuild/frontend.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

# Terraformのみ（手動イメージビルド後）
cd terraform
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

## 制限事項とトレードオフ

この構成を採用する際は、以下の制限事項とトレードオフを理解しておく必要があります。

### 1. CDNの不在によるパフォーマンス劣化

**問題点：**
- Cloud Run + Nginxでの静的ファイル配信は、デフォルトではGoogleのグローバルCDN（Cloud CDN）のエッジキャッシュが効きません
- Firebase HostingやGCS + Cloud Load Balancerのような構成と比較して、以下のデメリットがあります：
  - 地理的に遠いユーザーへの配信が遅くなる
  - Flutter Webのような大きなJavaScriptバンドル（main.dart.js）の初期ロードに時間がかかる
  - Cloud Runのコールドスタートの影響を受ける

**対策：**
- `Cache-Control` ヘッダーを適切に設定（本サンプルでは実装済み）
- Cloud Load BalancerをフロントエンドのCloud Runサービスの前段に配置し、Cloud CDNを有効化
- 頻繁にアクセスされる静的アセットはGCSなど別のストレージに配置することも検討

**トレードオフ：**
- シンプルさ vs パフォーマンス
- 単一コンテナ構成（コスト効率◎）vs CDN利用（パフォーマンス◎）

### 2. アーキテクチャの複雑さ

**追加の考慮事項：**
- Nginxの設定管理が必要（nginx.conf、proxy_params_commonなど）
- マルチステージビルドによるDockerイメージのビルド時間増加
- 環境変数の置換処理（docker-entrypoint.sh）のメンテナンス

**代替案との比較：**

| 構成 | メリット | デメリット |
|------|---------|-----------|
| **本構成（Nginx Reverse Proxy）** | - CORS問題の解消<br>- バックエンドの直接公開防止<br>- 単一エンドポイント | - CDN不在<br>- Nginx設定の管理<br>- ビルド複雑化 |
| **Firebase Hosting + Cloud Run** | - CDN標準装備<br>- 簡単な設定 | - Firebase依存<br>- CORS設定必要<br>- バックエンドURL露出 |
| **GCS + Cloud Load Balancer + Cloud Run** | - CDN利用可能<br>- 高パフォーマンス | - インフラ複雑化<br>- コスト増加<br>- CORS設定必要 |

### 3. セキュリティの誤解に注意

**この構成で守れること：**
- ✅ バックエンドのURL/エンドポイントの隠蔽
- ✅ バックエンドへの直接アクセスの防止
- ✅ 攻撃対象の表面積削減

**この構成で守れないこと：**
- ❌ アプリケーションレベルの認証・認可（別途実装必須）
- ❌ Nginx経由でのAPIアクセス制御（無条件プロキシ）
- ❌ 同じVPC内からの不正アクセス（IAM認証が必要）

### 4. スケーリングとコスト

**考慮点：**
- Nginxコンテナが静的ファイル配信とプロキシの両方を担うため、トラフィック増加時に両方がスケールします
- 静的ファイルのみのトラフィックでもCloud Runインスタンスが起動するため、CDN構成よりコストが高くなる可能性があります

**コスト最適化：**
- Cloud Runの最小インスタンス数を0に設定（コールドスタート許容の場合）
- 静的アセットに長いCache-Controlを設定してブラウザキャッシュを活用
- アクセスパターンに応じて、静的ファイルとAPIを別サービスに分離することも検討

## まとめ

このリポジトリでは、**バックエンドを内部通信のみに制限しながら、Nginxリバースプロキシでフロントエンドからアクセス可能にする**実践的な構成を紹介しました。

### 実現したこと

1. **バックエンドへの直接アクセス防止**
   - Docker Composeでは `expose` を使用
   - Cloud Runでは `ingress: internal` を設定
   - 外部からの直接アクセスを完全にブロック
   - ⚠️ ただし、アプリケーションレベルの認証は別途実装が必要

2. **CORS問題の根本的解決**
   - ブラウザから見ると単一オリジン
   - バックエンドにCORS設定不要

3. **ネットワークレイヤーでのセキュリティ向上**
   - バックエンドURL/エンドポイントの隠蔽
   - 攻撃対象の表面積削減
   - Nginxでセキュリティ対策を一元管理可能

4. **シンプルなインフラ構成**
   - ローカル開発からCloud Runまで同じ構成
   - 環境変数での柔軟な設定

### この構成が適している場合

✅ **推奨される場合：**
- バックエンドAPIのURL/エンドポイントを外部に公開したくない
- CORS問題を根本的に解決したい
- フロントエンドとバックエンドを統合的にデプロイしたい
- 小〜中規模のアプリケーション（トラフィックが限定的）

⚠️ **慎重に検討すべき場合：**
- 大規模トラフィックが予想される（CDN構成の方が適切）
- 静的ファイルの配信パフォーマンスが最重要（Firebase Hosting等が適切）
- バックエンドとフロントエンドを独立してスケールさせたい

### 本番環境での追加実装が推奨される項目

この構成を本番環境で使用する場合、以下の追加実装を強く推奨します：

1. **バックエンド側の認証・認可**
   - JWT検証、セッション管理など
   - APIキーによるアクセス制御

2. **Cloud RunのIAM認証**
   - `allUsers` ではなく特定のサービスアカウントに `run.invoker` を付与
   - NginxからMetadata ServerでIDトークンを取得

3. **Nginxでのセキュリティ強化**
   - レート制限（`limit_req_zone`）
   - 特定パスへのアクセス制限
   - セキュリティヘッダーの追加（CSP、X-Frame-Optionsなど）

4. **パフォーマンス最適化**
   - Cloud Load Balancer + Cloud CDNの前段配置を検討
   - 静的アセットの別ストレージ化

モダンなWebアプリケーション開発において、Nginxは単なるWebサーバーではなく、**ネットワークレイヤーでのセキュリティとアーキテクチャを支える重要なコンポーネント**として活用できます。ただし、アプリケーションレベルのセキュリティは別途実装が必要であることを忘れないでください。

## 参考リンク

- [Nginx公式ドキュメント - リバースプロキシ](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Flutter Web](https://flutter.dev/web)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Docker マルチステージビルド](https://docs.docker.com/build/building/multi-stage/)
- [Google Cloud Run](https://cloud.google.com/run)
