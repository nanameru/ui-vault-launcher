#!/usr/bin/env bash
# マイグレーション適用してからデプロイ。DB はバインディング名（買い手が DB 名を変えても通る）。
set -euo pipefail
cd "$(dirname "$0")"
pnpm exec wrangler d1 migrations apply DB --remote
pnpm exec wrangler deploy
