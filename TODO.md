# prremote TODO

## セットアップ
- [x] gemspec作成
- [x] Gemfile作成
- [x] ディレクトリ構造の構築 (lib/, bin/, test/)
- [x] bin/prremote エントリーポイント作成

## コア実装
- [x] シリアルポート自動検出 (`lib/prremote/detector.rb`)
- [x] シリアル通信基盤 (`lib/prremote/connection.rb`)
- [x] CLIエントリーポイント (`lib/prremote/cli.rb`)

## コマンド実装
- [x] `repl` — インタラクティブREPL
- [x] `ls [path]` — ファイル一覧
- [x] `put <local> [remote]` — アップロード
- [x] `get <remote> [local]` — ダウンロード
- [x] `run <file.rb>` — スクリプト実行
- [x] `eval <expr>` — 式評価
- [x] `rm <path>` — ファイル削除
- [x] `mkdir <path>` — ディレクトリ作成
- [x] `version` — バージョン表示
- [x] `list` — 接続可能デバイス一覧

## テスト (Minitest)
- [x] test/test_helper.rb
- [x] detector のテスト
- [x] connection のテスト
- [ ] 各コマンドのテスト (ls/put/get/run/eval/rm/mkdir)

## パッケージング
- [x] LICENSE
- [x] CI設定 (.github/workflows/ci.yml)
- [x] RuboCop設定 (.rubocop.yml)
- [ ] CHANGELOG.md
- [ ] RuboCop lint パス確認
