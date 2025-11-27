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

**重要：バックエンドは `expose` で内部通信のみに制限され、外部から直接アクセスできません。**

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

**Cloud Runでは、バックエンドの `ingress: internal` 設定により、外部からの直接アクセスを完全にブロックします。**

## なぜこの構成が必要なのか？

### 1. バックエンドを内部通信のみに制限（最重要）

**セキュリティ上の理由から、バックエンドAPIを直接インターネットに公開したくない場合があります：**

- 不正なアクセスやAPIの直接呼び出しを防ぐ
- DDoS攻撃などの標的になるリスクを軽減
- エンドポイントの探索による脆弱性の発見を防ぐ
- 内部サービス間通信として設計されたAPIを保護

**しかし、単純にバックエンドを内部通信のみにすると、フロントエンドからアクセスできません。**

#### 解決策：Nginxリバースプロキシ

Nginxをリバースプロキシとして配置することで：

- **バックエンドは内部通信のみに制限**（Docker Composeの `expose`、Cloud Runの `ingress: internal`）
- **フロントエンドはNginx経由でバックエンドにアクセス可能**
- **外部からはNginxのみが公開され、バックエンドは完全に隠蔽**

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

## まとめ

このリポジトリでは、**バックエンドを内部通信のみに制限しながら、Nginxリバースプロキシでフロントエンドからアクセス可能にする**実践的な構成を紹介しました。

### 実現したこと

1. **バックエンドの完全な隠蔽**
   - Docker Composeでは `expose` を使用
   - Cloud Runでは `ingress: internal` を設定
   - 外部からの直接アクセスを完全にブロック

2. **CORS問題の根本的解決**
   - ブラウザから見ると単一オリジン
   - バックエンドにCORS設定不要

3. **セキュリティの向上**
   - バックエンドAPIを保護
   - Nginxでセキュリティ対策を一元管理

4. **シンプルなインフラ構成**
   - ローカル開発からCloud Runまで同じ構成
   - 環境変数での柔軟な設定

### この構成が適している場合

- バックエンドAPIを直接インターネットに公開したくない
- セキュリティを重視したアーキテクチャを構築したい
- CORS問題を根本的に解決したい
- フロントエンドとバックエンドを統合的にデプロイしたい

モダンなWebアプリケーション開発において、Nginxは単なるWebサーバーではなく、**セキュリティとアーキテクチャを支える重要なコンポーネント**として活用できます。

## 参考リンク

- [Nginx公式ドキュメント - リバースプロキシ](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Flutter Web](https://flutter.dev/web)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Docker マルチステージビルド](https://docs.docker.com/build/building/multi-stage/)
- [Google Cloud Run](https://cloud.google.com/run)
