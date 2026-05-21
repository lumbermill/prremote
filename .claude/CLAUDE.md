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
# 2. Gemfile.lock を更新
bundle install

# 3. ローカルキャッシュにビルドを配置
cd runtime/
rake cache     # ビルド（pico + picow）→ ~/.prremote/runtime/ にコピー

# 4. GitHub draft リリース作成（UF2 アップロード）
rake release
# → draft のため GitHub 上でリリースノートを編集してから [Publish release]
cd ..

# 5. テスト
bundle exec rake test

# 6. gem ビルド
bundle exec rake gem            # pkg/prremote-X.X.X.gem が生成される

# 7. RubyGems.org に push（MFA 有効のため OTP が必要）
gem push pkg/prremote-X.X.X.gem --otp <認証アプリの6桁コード>

# 8. git タグを打って push
git tag vX.X.X
git push origin main vX.X.X
```

タグ名: ランタイムは `runtime-X.X.X`、gem は `vX.X.X`（どちらも同じバージョン番号）。

---

## 設計方針

### ランタイム（`runtime/src/`）の層別方針

#### C 層（`bindings.c`, `bindings_cyw43.c`）— picoruby を参照しつつ独自実装
- pico-sdk の API を mruby/c に直接バインドする独自コード。
- picoruby の C ポート（`ports/rp2040/cyw43.c` 等）は**設計参照・部分引用**してよい。
  コピーした箇所はコメントで出典ファイルパスを明記すること。
- ネットワーク層（`picoruby-socket`）の C ソースは**そのまま取り込む**。
  `picoruby_compat.h` で mruby/c ABI に橋渡しし、submodule update で追従できる状態を維持する。

#### Ruby 層（`hw_wrap.rb`, `cyw43_wrap.rb`）— **独自 API に振り切る**
- picoruby の Ruby クラス・メソッド名に縛られない。
  GPIO のビットフラグ方式など、picoruby の設計が冗長・複雑な箇所は prremote の API を優先する。
- ただし **WiFi / ネットワーク**（`CYW43`、`TCPSocket` 等）は picoruby 互換 API を維持する。
  理由：`picoruby-socket` の Ruby バイトコードをそのまま使っており、
  ユーザースクリプトの移植性も高い領域であるため。
- picoruby との非互換を選んだ箇所は `hw_wrap.rb` 冒頭コメントのように差異を明記する。

#### サンプル・ドキュメント方針
- 独自 API を採用した以上、`test/samples/` のサンプルと将来の README / docs が
  picoruby に代わる唯一の参照になる。
- 新しいペリフェラル対応を追加したら**必ずサンプル `.rb` も同時にコミット**する。
- サンプルは「コピペで動く」を原則とし、コメントで配線情報まで記載する（既存サンプル踏襲）。
