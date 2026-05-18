# prremote — 開発メモ

## 初回セットアップ

```bash
bundle install
rake setup      # pre-push フックをインストール（bundle check + rubocop を自動実行）
```

## リリース手順

### ランタイム (runtime/)

バージョンは `runtime/CMakeLists.txt` の `RUNTIME_VERSION` で管理。

```bash
cd runtime/
rake release        # ビルド（pico + picow）→ GitHub draft リリース作成 → UF2 アップロード
```

内部でやること:
1. `rake build:picow` → `build/picow/prremote-picow-runtime-X.X.X.uf2`
2. `rake build:pico`  → `build/pico/prremote-pico-runtime-X.X.X.uf2`
3. `gh release create runtime-X.X.X --draft --generate-notes` で両 UF2 をアップロード
4. draft のため GitHub 上でリリースノートを編集してから [Publish release]

タグ名は `runtime-X.X.X`（gem の `vX.X.X` とは別系統）。

### gem (prremote)

バージョンは `lib/prremote/version.rb` の `VERSION` / `RUNTIME_VERSION` で管理。

```bash
# 1. バージョンを上げた後は必ず実行（Gemfile.lock を更新）
bundle install

# 2. テスト
bundle exec rake test

# 3. gem ビルド
bundle exec rake gem            # pkg/prremote-X.X.X.gem が生成される

# 4. RubyGems.org に push（MFA 有効のため OTP が必要）
gem push pkg/prremote-X.X.X.gem --otp <認証アプリの6桁コード>

# 5. git タグを打って push
git tag vX.X.X
git push origin main vX.X.X
```

`RUNTIME_VERSION` を上げるときは、先にランタイムをリリースしてから gem をリリースする。
