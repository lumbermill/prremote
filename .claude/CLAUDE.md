# prremote — 開発メモ

## 初回セットアップ

```bash
bundle install
rake setup      # pre-push フックをインストール（bundle check + rubocop を自動実行）
```

## リリース手順

バージョンは **リポジトリルートの `VERSION` ファイルのみ**で管理。
`runtime/CMakeLists.txt` と `lib/prremote/version.rb` は両方とも `VERSION` から読み込む。

```bash
# 1. VERSION ファイルを編集（例: 0.1.5）
# 2. CHANGELOG.md の [Unreleased] セクションをバージョン番号と日付に確定
#    例: ## [0.1.5] - 2026-05-23
# 3. README.md の version コマンド出力例のバージョン番号を更新
# 4. Gemfile.lock を更新
bundle install

# 5. ローカルキャッシュにビルドを配置
cd runtime/
rake cache     # ビルド（pico + picow + esp32）→ ~/.prremote/runtime/ にコピー
# 注: esp32 ビルドには ESP-IDF v5.3 が必要（デフォルト ~/sources/esp/esp-idf、
#     submodule ではない。セットアップ手順は README.md の Development 参照。
#     別の場所なら IDF_PATH で指定）

# 6. runtime タグを push → CI（.github/workflows/ci.yml）が全ボードをビルドし、
#    リリースノートを CHANGELOG.md の該当バージョン節から取って publish まで自動実行
#    （手順 2 で CHANGELOG を確定させていることが前提）
cd ..
git tag runtime-X.X.X
git push origin main runtime-X.X.X
# フォールバック（CI が使えないとき）: cd runtime && rake release → draft を手動 publish
#   （既にリリースが存在する場合、CI は資産アップロードだけやり直す・冪等）

# 7. テスト
bundle exec rake test

# 8. gem ビルド
bundle exec rake gem            # pkg/prremote-X.X.X.gem が生成される

# 9. RubyGems.org に push（MFA 有効のため OTP が必要）
gem push pkg/prremote-X.X.X.gem --otp <認証アプリの6桁コード>

# 10. git タグを打って push
git tag vX.X.X
git push origin main vX.X.X
```

---

## 設計方針

### ランタイム（`runtime/src/`）の層別方針

#### プラットフォーム抽象（`prr_platform.h`）
- シリアルプロトコル本体 `runtime.c` はプラットフォーム中立。
  ボード固有部は `platform_pico.c`（pico-sdk）と `esp32/main/platform_esp32.c`（ESP-IDF）が実装。
- ESP32 ビルドは `runtime/esp32/` の ESP-IDF プロジェクト（v5.3、vendored しない）。
  C バインディングは `esp32/main/bindings_esp32.c` が `bindings.c` と同名・同シグネチャで実装し、
  Ruby 層（`hw_wrap.rb`, `lcd_wrap.rb`）は両ビルドで共有する。

#### C 層（`bindings.c`, `bindings_cyw43.c`, `esp32/main/bindings_esp32.c`）— picoruby を参照しつつ独自実装
- pico-sdk / ESP-IDF の API を mruby/c に直接バインドする独自コード。
- picoruby の C ポート（`ports/rp2040/cyw43.c` 等）は**設計参照・部分引用**してよい。
  コピーした箇所はコメントで出典ファイルパスを明記すること。
- ネットワーク層（`picoruby-socket`）の C ソースは**そのまま取り込む**。
  `picoruby_compat.h` で mruby/c ABI に橋渡しし、submodule update で追従できる状態を維持する。

#### Ruby 層（`hw_wrap.rb`, `cyw43_wrap.rb`）— **独自 API に振り切る**
- picoruby の Ruby クラス・メソッド名に縛られない。
  GPIO のビットフラグ方式など、picoruby の設計が冗長・複雑な箇所は prremote の API を優先する。

#### サンプル・ドキュメント方針
- 独自 API を採用した以上、`examples/` のサンプルと将来の README / docs が
  picoruby に代わる唯一の参照になる。
- 新しいペリフェラル対応を追加したら**必ずサンプル `.rb` も同時にコミット**する。
- サンプルは「コピペで動く」を原則とし、コメントで配線情報まで記載する（既存サンプル踏襲）。
