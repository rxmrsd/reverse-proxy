# Nginxをリバースプロキシとして活用する：Flutter Web + FastAPI構成の実践

## はじめに

このリポジトリは、Nginxのリバースプロキシ機能を理解するためのサンプルアプリケーションです。

モダンなWebアプリケーション開発において、フロントエンドとバックエンドを分離することは一般的になりました。しかし、CORS（Cross-Origin Resource Sharing）の問題や、デプロイの複雑さといった課題に直面することがあります。

**Nginxをリバースプロキシとして配置することで、これらの課題を解決できます。**

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                    ブラウザ                              │
│                 http://localhost                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Nginx (Port 80)                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Location /        → Flutter静的ファイル配信    │   │
│  │  Location /api/*   → バックエンドにプロキシ     │   │
│  └─────────────────────────────────────────────────┘   │
└──────────────┬──────────────────────┬───────────────────┘
               │                      │
               │                      │ proxy_pass
               │                      │
               ▼                      ▼
    ┌──────────────────┐   ┌──────────────────┐
    │  Flutter Web     │   │  FastAPI         │
    │  (静的ファイル)   │   │  (Port 8000)     │
    └──────────────────┘   └──────────────────┘
```

## Nginxをリバースプロキシとして使う意義

### 1. CORS問題の解消

通常、フロントエンドとバックエンドが異なるオリジン（プロトコル、ドメイン、ポートのいずれかが異なる）で動作する場合、ブラウザのセキュリティ機能によりCORSエラーが発生します。

```
フロントエンド: http://localhost:3000
バックエンド:   http://localhost:8000
→ 異なるポート = 異なるオリジン = CORSエラー
```

**Nginxをリバースプロキシとして配置すると**：

```
ブラウザ → http://localhost/         (フロントエンド)
ブラウザ → http://localhost/api/*    (バックエンド)
→ 同じオリジン = CORS問題なし
```

ブラウザから見ると、すべてのリクエストが同じオリジン（`http://localhost`）に対して行われるため、CORS設定が不要になります。

### 2. 単一エントリーポイント

ユーザーは1つのURLだけを知っていれば良く、フロントエンドとバックエンドの内部構成を意識する必要がありません。

### 3. セキュリティの向上

- バックエンドAPIを直接インターネットに公開せず、Nginxを通してのみアクセス可能にできる
- Nginxでレート制限、IP制限、認証などのセキュリティ対策を一元管理できる
- セキュリティヘッダー（CSP、X-Content-Type-Optionsなど）を統一的に設定できる

### 4. パフォーマンスの最適化

- 静的ファイルのキャッシング
- gzip圧縮の有効化
- コネクションのkeepalive設定
- 負荷分散（複数のバックエンドサーバーがある場合）

### 5. デプロイの簡素化

- フロントエンドとバックエンドをまとめて1つのコンテナ/サービスとしてデプロイ可能
- インフラ構成がシンプルになる
- 環境変数でバックエンドURLを動的に変更可能

## プロジェクト構成

```
reverse-proxy/
├── frontend/              # Flutter Webアプリケーション
│   ├── lib/
│   │   └── main.dart     # Flutterアプリケーションコード
│   ├── web/              # Webアセット
│   ├── Dockerfile        # マルチステージビルド（Flutter + Nginx）
│   ├── nginx.conf        # Nginx設定ファイル（テンプレート）
│   ├── proxy_params_common  # プロキシ共通設定
│   ├── docker-entrypoint.sh # 起動時設定スクリプト
│   ├── pubspec.yaml      # Flutter依存関係
│   └── cloudbuild.yaml   # Cloud Build設定（フロントエンド）
│
├── backend/              # FastAPIアプリケーション
│   ├── main.py           # FastAPIアプリケーションコード
│   ├── requirements.txt  # Python依存関係
│   ├── Dockerfile        # Dockerイメージ設定
│   └── cloudbuild.yaml   # Cloud Build設定（バックエンド）
│
├── terraform/            # Terraformインフラ定義
│   ├── main.tf           # プロバイダー設定
│   ├── variables.tf      # 変数定義
│   ├── backend.tf        # バックエンドCloud Runサービス
│   ├── frontend.tf       # フロントエンドCloud Runサービス
│   ├── terraform.tfvars.example  # 変数ファイル例
│   └── .gitignore        # Terraform用.gitignore
│
├── compose.yaml          # Docker Compose設定
├── cloudbuild.yaml       # Cloud Build設定（全体）
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

## 実際のプロジェクトでの活用例

このパターンは [retail-ai-inc/toppy](https://github.com/retail-ai-inc/toppy) プロジェクトで実際に採用されています。

- Flutter WebフロントエンドをNginxで配信
- `/toppie/*` パスへのリクエストをバックエンドにプロキシ
- Cloud Run上でコンテナとしてデプロイ
- セキュリティヘッダー（CSP等）の設定
- Google認証などの外部サービスとの統合

## Cloud Runへのデプロイ

このアプリケーションはGoogle Cloud Runにデプロイできます。詳細な手順は [DEPLOYMENT.md](DEPLOYMENT.md) を参照してください。

```bash
# Cloud Buildで一括デプロイ
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

# Terraformでデプロイ
cd terraform
terraform init
terraform apply
```

## まとめ

Nginxをリバースプロキシとして活用することで：

1. **CORS問題を根本的に解決**できる
2. **セキュリティとパフォーマンスを向上**させられる
3. **デプロイとインフラ管理を簡素化**できる
4. **フロントエンドとバックエンドの分離を保ちつつ、統合的に配信**できる

モダンなWebアプリケーション開発において、Nginxは単なるWebサーバーではなく、**アーキテクチャを支える重要なコンポーネント**として活用できます。

## 参考リンク

- [Nginx公式ドキュメント - リバースプロキシ](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Flutter Web](https://flutter.dev/web)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Docker マルチステージビルド](https://docs.docker.com/build/building/multi-stage/)
- [Google Cloud Run](https://cloud.google.com/run)
