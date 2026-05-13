# prremote TODO

## セットアップ
- [x] gemspec作成
- [x] Gemfile作成
- [x] ディレクトリ構造の構築 (lib/, bin/, test/)
- [x] bin/prremote エントリーポイント作成

## コア実装
- [x] シリアルポート自動検出 (`lib/prremote/detector.rb`)
- [x] シリアル通信基盤 (`lib/prremote/connection.rb`)
- [x] 独自シリアルプロトコル (`send_line` / `read_line` / `write_bytes` / `read_bytes`)
- [x] CLIエントリーポイント (`lib/prremote/cli.rb`)

## コマンド実装 (ホスト側)
- [x] `list` — 接続可能デバイス一覧
- [x] `ls [path]` — ファイル一覧
- [x] `put <local> [remote]` — アップロード
- [x] `get <remote> [local]` — ダウンロード
- [x] `cp <src> <dest>` — デバイス上でコピー
- [x] `eval <expr>` — 式評価
- [x] `rm <path>` — ファイル削除
- [x] `mkdir <path>` — ディレクトリ作成
- [x] `watch <local> [remote]` — 変更を監視して自動 put + reset
- [x] `reset` — デバイスリセット
- [x] `install` — ファームウェアのダウンロード・書き込み
- [x] `version` — バージョン表示

## テスト (Minitest)
- [x] test/test_helper.rb (FakeConnection)
- [x] detector のテスト
- [x] connection のテスト
- [x] 各コマンドのテスト (ls/put/get/cp/eval/rm/mkdir)

## パッケージング
- [x] LICENSE
- [x] CI設定 (.github/workflows/ci.yml)
- [x] RuboCop設定 (.rubocop.yml)
- [ ] CHANGELOG.md
- [ ] RuboCop lint パス確認

---

## 次の大課題: ファームウェア実装

prremote-agent (デバイス側) の実装。別リポジトリ `prremote/firmware` として管理予定。

### 構成
```
mruby/c VM
+ picoruby-gpio
+ picoruby-cyw43  (Pico W のみ)
+ prremote-agent  ← 自作: シリアルコマンドを受け付ける薄いレイヤー
```

### prremote-agent が実装すべきコマンド
- [ ] `PUT /path SIZE` → `READY` → binary → `OK|ERROR`
- [ ] `GET /path` → `SIZE n` → binary
- [ ] `LS [/path]` → entries… → `END`
- [ ] `RM /path` → `OK|ERROR`
- [ ] `MKDIR /path` → `OK|ERROR`
- [ ] `CP src dst` → `OK|ERROR`
- [ ] `EVAL expr` → `OK result|ERROR msg`
- [ ] `RESET` → デバイスリセット
- [ ] `VERSION` → バージョン文字列

### ビルド・配布
- [ ] Raspberry Pi Pico 向け UF2 ビルド
- [ ] Raspberry Pi Pico W 向け UF2 ビルド
- [ ] GitHub Releases への UF2 自動アップロード (CI)
- [ ] `prremote install` が取得できるリリースタグ・ファイル名の規約を確定
