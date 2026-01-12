# IaC デプロイ用 CodePipeline（GitHub ソース）

概要

- パイプラインのステージ:
  - ソース: CodeStar Connection 経由で GitHub リポジトリを取得
  - ビルド: YAML の lint と CloudFormation ChangeSet の作成（実行はしない）
  - 承認: 人による ChangeSet の確認（手動承認）
  - デプロイ: ChangeSet を実行してスタックを作成/更新

使い方

1. AWS コンソールで CodeStar Connection を作成し、GitHub と連携して許可します。Connection ARN を控えてください。

2. Secrets Manager に GitHub 用のデプロイ鍵（秘密鍵のプレーンテキスト、パスフレーズ無し）を保存します。例:

```bash
aws secretsmanager create-secret --name github/deploy-key --description "Private key for CodeBuild to access GitHub" --secret-string "$(cat github_deploy_key)"
```

3. パイプラインスタックをデプロイします（Connection ARN と Secret ARN を指定）:

```bash
./deploy-pipeline.sh aws-demo-pipeline arn:aws:codestar-connections:us-east-1:123456789012:connection/EXAMPLE arn:aws:secretsmanager:us-east-1:123456789012:secret:github/deploy-key lizheng9824/aws-demo-infra
```

パイプラインの変更点（本リポジトリへの反映）

- CloudFormation テンプレートに `GitHubSecretArn` パラメータを追加し、CodeBuild 実行ロールにその ARN に対する `secretsmanager:GetSecretValue` を許可しました。
- 2 つの CodeBuild プロジェクトには inline の `buildspec` を組み込み、ビルド開始時に Secrets Manager から秘密鍵を取得して SSH を設定する処理を追加しています。処理の流れ:
  - 秘密鍵を `/root/.ssh/id_ed25519` に書き込み
  - ファイル権限を `chmod 600` に設定
  - `ssh-keyscan github.com` で `known_hosts` を作成
  - `GIT_SSH_COMMAND` を設定して `git` コマンドでその鍵を使う
  - その後既存の lint / ChangeSet 作成・実行処理を実行

セキュリティ上の注意

- Secrets Manager のシークレットには秘密鍵のみ（プレーンテキスト）を保存してください。
- Secrets の参照権限は必要最小限の ARN に限定してください。
- このテンプレートは簡便化のため一部権限が広めに設定されています。本番運用前に IAM を厳密に絞ってください。

追加で対応可能なこと

- `deploy-pipeline.sh` を `GitHubSecretArn` を受け取って検証するように更新します。
- CodeBuild 実行ロールに割り当てる最小権限の IAM ポリシー（JSON）を生成します。
- inline の `buildspec` をリポジトリ内のファイルに移動し、CodeBuild がそれを参照するようテンプレートを変更します。
