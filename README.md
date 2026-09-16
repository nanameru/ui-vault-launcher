# ui-vault-launcher

UIギャング（UI Gang、旧 UI Vault）を自分の Cloudflare アカウントにボタン 1 回で建てるためのランチャーです。**本体コードは含まれません**。ビルド時に合言葉で Taiyo AI Hub の配布サーバから取得します。

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/nanameru/ui-vault-launcher)

## 手順

1. note 記事または Taiyo AI Hub で版を購入し、合言葉を受け取る
2. 上のボタンを押す
3. セットアップ画面で `RELEASE_KEY`（合言葉）と `API_TOKEN`（自分で `openssl rand -base64 32` などで生成）を入力
4. デプロイ完了後の URL を開き、設定（歯車）→ API トークンに `API_TOKEN` を貼る
5. MCP 登録:
   - Claude Code: `claude mcp add --transport http ui-vault https://<worker>.workers.dev/mcp --header "Authorization: Bearer <API_TOKEN>"`
   - Codex: `export UI_VAULT_TOKEN=<API_TOKEN>` → `codex mcp add ui-vault --url https://<worker>.workers.dev/mcp --bearer-token-env-var UI_VAULT_TOKEN`

## ビルドが「RELEASE_KEY がビルド環境にありません」で失敗する場合

セットアップ画面の値がビルド環境に載らない環境では、Cloudflare ダッシュボード → Workers & Pages → ui-vault → Settings → Build → Variables and secrets に `RELEASE_KEY`（合言葉）を追加して Retry build してください。

## 新しい版への更新

新しい版の合言葉を受け取ったら、`wrangler.jsonc` の `UI_VAULT_RELEASE` を書き換え、Build variables の `RELEASE_KEY` も更新して push してください（自動で再ビルド・再デプロイされます）。

## 推奨: ログイン保護

ブラウザに API トークンを置きたくない場合は、Cloudflare Access で前段を保護できます。手順は本体の ZIP に入っている `README.md` の「推奨構成」節と `AGENT-DEPLOY.md` を参照してください。

## ライセンス

このランチャーは MIT。本体（UIギャング）は購入時の `LICENSE.txt` に従います。
