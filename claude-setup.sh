#!/bin/bash
# WFF Inc. Mac セットアップ（Claude Code 実行用）。ターミナルを使わず、必要な入力は macOS のダイアログで行う。
# 使い方: bash ~/.wff/claude-setup.sh <check|fix-claude-app|admin|repo|repo-wait|install|browser|line|doctor>
set -u
export LANG="${LANG:-ja_JP.UTF-8}" LC_ALL="${LC_ALL:-ja_JP.UTF-8}" WFF_GUI=1
W="$HOME/.wff"; mkdir -p "$W"; chmod 700 "$W"
BASE="https://raw.githubusercontent.com/wff-inc/mac-bootstrap/main"
DEST="$HOME/wff-mac-setup"
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f "$W/askpass.sh" ] || curl -fsSL "$BASE/askpass.sh" -o "$W/askpass.sh"; chmod 700 "$W/askpass.sh"
export SUDO_ASKPASS="$W/askpass.sh"
ok(){ printf 'OK   %s\n' "$1"; }; warn(){ printf 'WARN %s\n' "$1"; }; fail(){ printf 'FAIL %s\n' "$1"; }

admin_run(){ # 管理者権限で1つのスクリプトを実行（パスワード入力窓が1回出る）
  local f="$1"
  osascript -e "do shell script \"/bin/bash '$f'\" with administrator privileges with prompt \"WFF Mac セットアップ：初期設定に管理者権限が必要です。このMacのログインパスワードを入力してください。\"" 2>&1
}

case "${1:-check}" in
check)
  echo "macos=$(sw_vers -productVersion) arch=$(uname -m) user=$USER fullname=$(id -F 2>/dev/null)"
  xcode-select -p >/dev/null 2>&1 && echo "clt=yes" || echo "clt=no"
  [ -x /opt/homebrew/bin/brew ] && echo "brew=yes" || echo "brew=no"
  [ -d "$DEST/.git" ] && echo "repo=yes" || echo "repo=no"
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && echo "gh_login=yes" || echo "gh_login=no"
  fdesetup status 2>/dev/null | grep -q On && echo "filevault=on" || echo "filevault=off"
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q enabled && echo "firewall=on" || echo "firewall=off"
  [ -d /Applications/LINE.app ] && echo "line=yes" || echo "line=no"
  ps -axo command 2>/dev/null | grep -q '^/Volumes/[^ ]*Claude.app' && echo "claude_from_dmg=yes" || echo "claude_from_dmg=no"
  [ -d "/Applications/Claude.app" ] && echo "claude_in_applications=yes" || echo "claude_in_applications=no"
  ;;
fix-claude-app)
  # Claude を取り込み用ディスク（.dmg）から直接起動している場合、アプリケーションフォルダにコピーする（ディスクの取り出しは本人が後で行う）
  if [ -d "/Applications/Claude.app" ]; then ok "Claude はアプリケーションフォルダにあります"; exit 0; fi
  SRC="$(ls -d /Volumes/*/Claude.app 2>/dev/null | head -1)"
  [ -n "$SRC" ] || { warn "取り込み用ディスクに Claude が見つかりません"; exit 0; }
  cp -R "$SRC" /Applications/ && ok "Claude をアプリケーションフォルダにコピーしました（作業後にアプリケーションフォルダから起動し直してもらう）"
  ;;
browser)
  # 既定ブラウザを Chrome に（macOSの確認ダイアログで本人が押す）
  CUR="$(python3 - <<'PY' 2>/dev/null
import plistlib,os
p=os.path.expanduser('~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist')
try:
    d=plistlib.load(open(p,'rb'))
    for h in d.get('LSHandlers',[]):
        if h.get('LSHandlerURLScheme')=='http': print(h.get('LSHandlerRoleAll','')); break
    else: print('')
except Exception: print('')
PY
)"
  if [ "$CUR" = "com.google.chrome" ]; then ok "既定ブラウザは既に Chrome"; exit 0; fi
  [ -d "/Applications/Google Chrome.app" ] || { warn "Chrome が未導入"; exit 0; }
  open -a "Google Chrome" --args --make-default-browser
  echo "WAITING 既定ブラウザの確認ダイアログが出ます。「“Google Chrome”を使用」を押してもらってください"
  ;;
admin)
  A="$W/admin-phase.sh"
  cat > "$A" <<ADM
#!/bin/bash
set -u
U="$USER"
echo "== 管理者フェーズ開始 =="
# Rosetta
/usr/bin/pgrep -q oahd || softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1 || true
# Xcode Command Line Tools（無人導入）
if ! xcode-select -p >/dev/null 2>&1; then
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  L=\$(softwareupdate -l 2>/dev/null | grep -o 'Command Line Tools for Xcode-[0-9.]*' | sort -V | tail -1)
  [ -n "\$L" ] && softwareupdate -i "\$L" >/dev/null 2>&1
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi
xcode-select -p >/dev/null 2>&1 && echo "clt=ok" || echo "clt=missing"
# Homebrew（公式 .pkg）
if [ ! -x /opt/homebrew/bin/brew ]; then
  curl -fsSL -o /tmp/Homebrew.pkg https://github.com/Homebrew/brew/releases/latest/download/Homebrew.pkg && installer -pkg /tmp/Homebrew.pkg -target / >/dev/null 2>&1
  rm -f /tmp/Homebrew.pkg
fi
[ -d /opt/homebrew ] && chown -R "\$U":admin /opt/homebrew 2>/dev/null || true
[ -x /opt/homebrew/bin/brew ] && echo "brew=ok" || echo "brew=missing"
# 会社標準：ファイアウォールON・自動更新ON
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null 2>&1 && echo "firewall=on"
P=/Library/Preferences/com.apple.SoftwareUpdate
for k in AutomaticCheckEnabled AutomaticDownload AutomaticallyInstallMacOSUpdates CriticalUpdateInstall ConfigDataInstall; do defaults write \$P \$k -bool true; done
defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true && echo "autoupdate=on"
echo "== 管理者フェーズ完了 =="
ADM
  chmod 700 "$A"
  admin_run "$A"; rc=$?
  rm -f "$A"
  [ $rc -eq 0 ] && ok "管理者フェーズ完了" || fail "管理者フェーズが中断されました（パスワード窓をキャンセルした可能性）"
  exit $rc
  ;;
repo)
  [ -x /opt/homebrew/bin/brew ] || { fail "Homebrew がありません。先に admin を実行してください"; exit 1; }
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  if [ -d "$DEST/.git" ]; then git -C "$DEST" pull -q --ff-only && ok "本体を最新にしました" ; exit 0; fi
  if [ -n "${WFF_TOKEN:-}" ]; then
    git clone -q "https://x-access-token:${WFF_TOKEN}@github.com/wff-inc/mac-setup.git" "$DEST" && git -C "$DEST" remote set-url origin "https://github.com/wff-inc/mac-setup.git" && ok "本体を取得しました（合言葉）"; exit $?
  fi
  brew list gh >/dev/null 2>&1 || brew install -q gh
  if gh auth status >/dev/null 2>&1; then gh repo clone wff-inc/mac-setup "$DEST" -- -q && ok "本体を取得しました（GitHub）"; exit $?; fi
  # GitHub のログインをバックグラウンドで開始し、8桁コードだけ返す（ブラウザは自動で開く）
  : > "$W/gh-login.log"
  ( gh auth login --web --git-protocol https -h github.com > "$W/gh-login.log" 2>&1; echo "gh_exit=$?" >> "$W/gh-login.log" ) &
  for i in $(seq 1 30); do grep -q "one-time code" "$W/gh-login.log" && break; sleep 1; done
  CODE=$(grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' "$W/gh-login.log" | head -1)
  if [ -n "$CODE" ]; then echo "WAITING code=$CODE url=https://github.com/login/device"; else fail "GitHubログインのコードを取得できませんでした"; cat "$W/gh-login.log"; exit 1; fi
  ;;
repo-wait)
  for i in $(seq 1 600); do grep -q "gh_exit=" "$W/gh-login.log" 2>/dev/null && break; sleep 1; done
  grep -q "gh_exit=0" "$W/gh-login.log" 2>/dev/null || { fail "GitHubログインが完了していません"; tail -3 "$W/gh-login.log"; exit 1; }
  gh repo clone wff-inc/mac-setup "$DEST" -- -q && ok "本体を取得しました（GitHub）"
  ;;
install)
  [ -f "$DEST/setup.sh" ] || { fail "本体がありません。先に repo を実行してください"; exit 1; }
  bash "$DEST/setup.sh"
  ;;
line)
  [ -d /Applications/LINE.app ] && { ok "LINE は導入済み"; exit 0; }
  open "macappstore://apps.apple.com/jp/app/line/id539883307" && echo "WAITING App Store の LINE ページを開きました。「入手」を押してもらってください"
  ;;
doctor)
  [ -f "$DEST/doctor.sh" ] || { fail "本体がありません"; exit 1; }
  bash "$DEST/doctor.sh"; echo "report=$HOME/Library/Logs/wff-doctor.md"
  ;;
*) echo "usage: claude-setup.sh <check|fix-claude-app|admin|repo|repo-wait|install|browser|line|doctor>"; exit 2;;
esac
