# Terraform Infrastructure

このディレクトリには、Google Cloud RunでフロントエンドとバックエンドをデプロイするためのTerraform構成が含まれています。

## 概要

この構成は以下をデプロイします:

1. **バックエンド**: FastAPI (1つのサービス)
2. **フロントエンド**: Flutter Web (同じアプリを異なる戦略で2つデプロイ)
   - **frontend-static** (Strategy 1: Direct Backend Access)
   - **frontend** (Strategy 2: Reverse Proxy)

## ディレクトリ構造

```
terraform/
├── main.tf                    # プロバイダー設定
├── variables.tf               # 入力変数
├── locals.tf                  # ローカル変数（デプロイメント戦略の設定を含む）
├── artifact_registry.tf       # Artifact Registry
├── backend.tf                 # バックエンドCloud Runサービス
├── frontend.tf                # フロントエンドデプロイメント（モジュール使用）
├── service_account.tf         # サービスアカウント
└── modules/
    └── frontend-proxy/              # フロントエンドモジュール
        ├── main.tf            # モジュールメイン
        ├── variables.tf       # モジュール変数
        ├── outputs.tf         # モジュール出力
        └── README.md          # モジュールドキュメント
```

## フロントエンドデプロイメント戦略

### 重要な注意事項

**両方のフロントエンドは同じFlutterアプリケーションを提供しています。違いはデプロイメント戦略のみです。**

この構成は、デプロイメント戦略の違いを明確にするためにモジュール化されています:

### Strategy 1: Direct Backend Access (`frontend-static`)

- **ディレクトリ**: `../frontend-static/`
- **サービス名**: `reverse-proxy-frontend-static`
- **デプロイメント戦略**: `direct-backend-access`
- **ポート**: 8080
- **動作**: ブラウザから直接バックエンドAPIを呼び出す
- **要件**: バックエンドが公開アクセス可能である必要がある

```hcl
module "frontend_static" {
  source = "./modules/frontend"

  deployment_strategy = "direct-backend-access"
  container_port      = 8080
  # BACKEND_URL環境変数は不要
}
```

### Strategy 2: Reverse Proxy (`frontend`)

- **ディレクトリ**: `../frontend-proxy/`
- **サービス名**: `reverse-proxy-frontend`
- **デプロイメント戦略**: `reverse-proxy`
- **ポート**: 80
- **動作**: Nginxがバックエンドへのリクエストをプロキシ
- **利点**: バックエンドを内部専用にできる（より安全）

```hcl
module "frontend_proxy" {
  source = "./modules/frontend"

  deployment_strategy = "reverse-proxy"
  container_port      = 80
  backend_url         = google_cloud_run_v2_service.backend.uri
}
```

## 共通設定

両方のフロントエンドデプロイメントは以下の共通設定を共有しています（`locals.tf`で定義）:

```hcl
frontend_common_config = {
  resources = {
    cpu    = "1"
    memory = "512Mi"
  }
  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }
  vpc = {
    network    = "proxy-subnet"
    subnetwork = "proxy-subnet3"
  }
  ingress = "INGRESS_TRAFFIC_ALL"
}
```

## デプロイ方法

### 前提条件

```bash
# GCPプロジェクトを設定
export PROJECT_ID="your-project-id"

# terraform.tfvarsを作成
cat > terraform.tfvars <<EOF
project_id = "${PROJECT_ID}"
EOF
```

### Terraformコマンド

```bash
# 初期化
terraform init

# プランを確認
terraform plan

# デプロイ
terraform apply

# デプロイメント戦略を確認
terraform output deployment_strategies
```

### 出力例

```bash
terraform output deployment_strategies
```

```json
{
  "frontend_proxy" = {
    "description" = "Reverse proxy - Nginx proxies to backend"
    "strategy" = "reverse-proxy"
    "url" = "https://reverse-proxy-frontend-xxx.run.app"
  }
  "frontend_static" = {
    "description" = "Static file serving - Browser calls backend directly"
    "strategy" = "direct-backend-access"
    "url" = "https://reverse-proxy-frontend-static-xxx.run.app"
  }
}
```

## モジュールの詳細

フロントエンドモジュールの詳細な説明は [modules/frontend-proxy/README.md](modules/frontend-proxy/README.md) を参照してください。

## 構成の改善点

### モジュール化による明確化

以前の構成では、2つのフロントエンドリソースが個別に定義されており、同じアプリケーションを提供していることが分かりにくい状態でした。

**改善後**:

1. **モジュール化** (`modules/frontend-proxy/`)
   - 共通のデプロイメントロジックを再利用可能なモジュールに抽出
   - デプロイメント戦略を明示的なパラメータとして定義
   - バリデーションを追加して設定ミスを防止

2. **設定の明確化** (`locals.tf`)
   - 共通設定 (`frontend_common_config`) を定義
   - 各デプロイメント戦略の違いを明示
   - コメントで各戦略の目的と違いを説明

3. **ドキュメント強化**
   - デプロイメント戦略の違いを詳細に説明
   - 使用ケースを明確化
   - 構成図の追加

**メリット**:

- デプロイメント戦略の違いが一目で分かる
- 共通設定の変更が容易
- DRY原則に準拠
- 将来的な拡張が容易（新しい戦略の追加など）
