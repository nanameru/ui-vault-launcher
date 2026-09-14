#!/usr/bin/env bash
# UI Vault 本体を合言葉で取得してビルドする。
# Deploy ボタンの build ステップとして Cloudflare が実行する想定。合言葉の値はログに出さない。
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "[ui-vault-launcher] $*" >&2; exit 1; }

# 1. 合言葉
[ -n "${RELEASE_KEY:-}" ] || fail "RELEASE_KEY がビルド環境にありません。Cloudflare ダッシュボード → Workers & Pages → ui-vault → Settings → Build → Variables and secrets に RELEASE_KEY（合言葉）を追加して Retry build してください"

# 2. UI_VAULT_RELEASE / UI_VAULT_UNLOCK_URL: env 優先、無ければ wrangler.jsonc の vars から
#    （jsonc の行頭・インデントのみに続く // コメント行を落として JSON.parse。URL 内の // は壊さない）
read_var() {
  VAR_NAME="$1" node -e '
    const fs = require("fs");
    try {
      const text = fs.readFileSync("wrangler.jsonc", "utf8")
        .split("\n").filter((l) => !/^\s*\/\//.test(l)).join("\n");
      const v = JSON.parse(text).vars?.[process.env.VAR_NAME];
      if (v) console.log(v);
    } catch {}
  '
}
RELEASE="${UI_VAULT_RELEASE:-$(read_var UI_VAULT_RELEASE)}"
UNLOCK_URL="${UI_VAULT_UNLOCK_URL:-$(read_var UI_VAULT_UNLOCK_URL)}"
[ -n "$RELEASE" ] || fail "UI_VAULT_RELEASE が見つかりません（wrangler.jsonc の vars を確認してください）"
[ -n "$UNLOCK_URL" ] || fail "UI_VAULT_UNLOCK_URL が見つかりません（wrangler.jsonc の vars を確認してください）"

# 3. 合言葉を unlock（password は stdin 経由で渡し、コマンドライン・ログに載せない）
UNLOCK_JSON=$(mktemp)
export UNLOCK_JSON
HTTP_CODE=$(printf '%s' "$RELEASE_KEY" \
  | node -e 'let s="";process.stdin.on("data",(d)=>s+=d).on("end",()=>process.stdout.write(JSON.stringify({password:s})))' \
  | curl -sS -o "$UNLOCK_JSON" -w '%{http_code}' -X POST \
      "$UNLOCK_URL/releases/$RELEASE/unlock" \
      -H 'content-type: application/json' --data-binary @-) \
  || fail "配布サーバに接続できませんでした: $UNLOCK_URL"

case "$HTTP_CODE" in
  200) ;;
  401|403) fail "合言葉が違う、またはこの版のものではありません（版: ${RELEASE}）" ;;
  404) fail "版 ${RELEASE} が見つかりません（配布側に登録されていない可能性があります）" ;;
  429) fail "試行回数の上限です。数分待って Retry build してください" ;;
  *) fail "unlock が失敗しました（HTTP $HTTP_CODE）: $(cat "$UNLOCK_JSON")" ;;
esac

DL_PATH=$(node -e 'const r=JSON.parse(require("fs").readFileSync(process.env.UNLOCK_JSON,"utf8"));console.log(r.path||"")' 2>/dev/null || true)
[ -n "$DL_PATH" ] || fail "unlock の応答にダウンロードパスがありません"
case "$DL_PATH" in
  http://*|https://*) DL_URL="$DL_PATH" ;;
  *) DL_URL="$UNLOCK_URL$DL_PATH" ;;
esac

# 4. ZIP 取得 → app/ へ展開
ZIP=/tmp/ui-vault-release.zip
curl -fsSL -o "$ZIP" "$DL_URL" || fail "ZIP の取得に失敗しました"
EXTRACT=$(mktemp -d)
unzip -q "$ZIP" -d "$EXTRACT" || fail "ZIP の展開に失敗しました"
TOP=$(find "$EXTRACT" -maxdepth 1 -mindepth 1 -type d -name 'ui-vault-*' | head -1)
[ -n "$TOP" ] || fail "ZIP の中に ui-vault-* ディレクトリがありません"
rm -rf app
mv "$TOP" app
rm -rf "$EXTRACT" "$ZIP" "$UNLOCK_JSON"

# 5. 本体の依存インストールとビルド
if ! command -v pnpm >/dev/null 2>&1; then
  corepack enable || fail "pnpm が見つからず corepack enable も失敗しました"
fi
(cd app && pnpm install --frozen-lockfile && pnpm build)

echo "[ui-vault-launcher] 取得した版: $RELEASE / ビルド完了"
