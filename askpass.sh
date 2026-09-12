#!/bin/bash
# sudo -A から呼ばれ、macOS標準のダイアログでパスワードを受け取って sudo にだけ渡す。
# 入力値は画面・ログ・Claudeの会話には出ない。
osascript \
  -e 'display dialog "WFF Mac セットアップ\n\nアプリ（Microsoft Office など）の導入に管理者権限が必要です。\nこのMacのログインパスワードを入力してください。" default answer "" with hidden answer with title "WFF Mac セットアップ" buttons {"OK"} default button "OK" with icon caution' \
  -e 'text returned of result' 2>/dev/null
