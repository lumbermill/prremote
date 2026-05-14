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

詳細は [firmware/PLAN.md](firmware/PLAN.md) を参照。

### agent.rb (デバイス側スクリプト)
- [x] `firmware/agent.rb` 作成 — プロトコル全コマンド実装済み

### prremote-agent が実装すべきコマンド
- [x] `PUT /path SIZE` → `READY` → binary → `OK|ERROR`
- [x] `GET /path` → `SIZE n` → binary
- [x] `LS [/path]` → entries… → `END`
- [x] `RM /path` → `OK|ERROR`
- [x] `MKDIR /path` → `OK|ERROR`
- [x] `CP src dst` → `OK|ERROR`
- [x] `EVAL expr` → `OK result|ERROR msg`
- [x] `RESET` → デバイスリセット
- [x] `VERSION` → バージョン文字列

### ビルド環境構築 (次のセッションの最初にやること)
- [ ] **[Step 1]** R2P2 のビルドの仕組みを調査する
      → agent.rb をどのように firmware に埋め込むか確認
      → 参考: https://github.com/picoruby/R2P2 の Rakefile / build_config/
- [ ] **[Step 2]** ローカルでビルドツールチェーンを確認・セットアップ
      → `arm-none-eabi-gcc`, `cmake`, `pico-sdk` の有無チェック
      → `rake r2p2:setup` (または相当コマンド) を試す
- [ ] **[Step 3]** `firmware/build_config/pico_w.rb` 作成
      → picoruby-uart / picoruby-machine / picoruby-littlefs / picoruby-cyw43 を含める
- [ ] **[Step 4]** Hello World レベルのビルドを通して UF2 生成を確認する
- [ ] **[Step 5]** agent.rb を組み込んで Pico W 向け UF2 をビルド・実機テスト
- [ ] **[Step 6]** 実機で `bundle exec rake integration` をパスさせる

### 動作未確認の懸念点 (実機テスト前に要確認)
- [ ] `eval(code)` が PicoRuby で使えるか → 使えなければ `Sandbox.new.eval(code)` に差し替え
- [ ] `File.delete` が存在するか → なければ C 拡張追加 or `File.unlink` 試行
- [ ] `uart.readpartial` がブロックせず部分読みできるか確認

### ビルド・配布
- [ ] Raspberry Pi Pico 向け UF2 ビルド
- [ ] Raspberry Pi Pico W 向け UF2 ビルド
- [ ] GitHub Releases への UF2 自動アップロード (CI)
- [ ] `prremote install` が取得できるリリースタグ・ファイル名の規約を確定
- [ ] GitHub workflowの整理(今は全部failedで終わる)