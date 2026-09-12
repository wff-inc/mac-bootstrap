#!/bin/bash
# WFF Inc. Mac ブートストラップ（公開用・内部情報を含めない）
# 新Macで最初に実行する1行:
#   bash <(curl -fsSL https://raw.githubusercontent.com/wff-inc/mac-bootstrap/main/bootstrap.sh)
# 管理者から読み取り専用トークンを渡された場合（GitHubアカウント不要）:
#   WFF_TOKEN=xxxx bash <(curl -fsSL https://raw.githubusercontent.com/wff-inc/mac-bootstrap/main/bootstrap.sh)
set -eu
echo "== WFF Mac セットアップを開始します =="
# 1. Xcode Command Line Tools（gitに必要。未導入なら案内ダイアログが出る）
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "画面の案内に従ってコマンドラインツールを入れ、終わったらもう一度この1行を実行してください"; exit 0
fi
# 2. Homebrew
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
# 3. 本体（非公開リポジトリ）を取得
DEST="$HOME/wff-mac-setup"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only || true
elif [ -n "${WFF_TOKEN:-}" ]; then
  git clone --quiet "https://x-access-token:${WFF_TOKEN}@github.com/wff-inc/mac-setup.git" "$DEST"
  git -C "$DEST" remote set-url origin "https://github.com/wff-inc/mac-setup.git"   # トークンを残さない
else
  brew list gh >/dev/null 2>&1 || brew install gh
  gh auth status >/dev/null 2>&1 || gh auth login --web --git-protocol https
  gh repo clone wff-inc/mac-setup "$DEST"
fi
exec bash "$DEST/setup.sh"
