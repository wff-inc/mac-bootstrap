# mac-bootstrap

WFF Inc. 社用Macセットアップの「入口」です。中身は `bootstrap.sh` 1本だけで、次のことしかしません。

1. Xcode Command Line Tools と Homebrew を入れる
2. 本体（非公開リポジトリ）を取得する
3. 本体の `setup.sh` を実行する

新しいMacのターミナルで次の1行を実行します。

```
bash <(curl -fsSL https://raw.githubusercontent.com/wff-inc/mac-bootstrap/main/bootstrap.sh)
```

このリポジトリには会社の内部情報・パスワード・トークンは一切含まれていません。
