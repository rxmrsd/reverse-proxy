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
├── main.tf                    # プロバイダー設定、VPCモジュール呼び出し
├── variables.tf               # 入力変数
├── locals.tf                  # ローカル変数（デプロイメント戦略の設定を含む）
├── artifact_registry.tf       # Artifact Registry
├── backend.tf                 # バックエンドCloud Runサービス
├── frontend.tf                # フロントエンドデプロイメント（モジュール使用）
├── service_account.tf         # サービスアカウント
└── modules/
    ├── vpc/                   # VPCネットワークモジュール
    │   ├── main.tf            # VPCリソース定義
    │   ├── variables.tf       # モジュール変数
    │   └── outputs.tf         # モジュール出力
    └── frontend/              # フロントエンドモジュール
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

## VPCネットワーク設定

VPCネットワークはモジュール化されており、`modules/vpc/`で管理されています:

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name  # デフォルト: "proxy-vpc"
  subnet_cidr  = var.subnet_cidr   # デフォルト: "10.10.0.0/24"
}
```

**VPCモジュールが作成するリソース:**
- VPCネットワーク
- サブネット（IPv4、プライベートGoogleアクセス有効）
- サービスネットワーキング接続（Cloud SQL等との接続用）

**カスタマイズ可能な変数:**
- `network_name`: VPC名（デフォルト: `proxy-vpc`）
- `subnet_cidr`: サブネットCIDR範囲（デフォルト: `10.10.0.0/24`）

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
    network    = module.vpc.network_name     # VPCモジュールの出力を参照
    subnetwork = module.vpc.subnet_name      # VPCモジュールの出力を参照
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

1. **フロントエンドのモジュール化** (`modules/frontend/`)
   - 共通のデプロイメントロジックを再利用可能なモジュールに抽出
   - デプロイメント戦略を明示的なパラメータとして定義
   - バリデーションを追加して設定ミスを防止

2. **VPCのモジュール化** (`modules/vpc/`)
   - VPCネットワーク構成を再利用可能なモジュールに抽出
   - ネットワーク設定の一元管理
   - 他のリソースからはモジュール出力を参照

3. **設定の明確化** (`locals.tf`)
   - 共通設定 (`frontend_common_config`) を定義
   - VPCモジュールの出力を参照
   - 各デプロイメント戦略の違いを明示
   - コメントで各戦略の目的と違いを説明

4. **ドキュメント強化**
   - デプロイメント戦略の違いを詳細に説明
   - VPCモジュールの構成を説明
   - 使用ケースを明確化
   - 構成図の追加

**メリット**:

- デプロイメント戦略の違いが一目で分かる
- ネットワーク構成が再利用可能で保守しやすい
- 共通設定の変更が容易
- DRY原則に準拠
- 将来的な拡張が容易（新しい戦略やネットワーク構成の追加など）
