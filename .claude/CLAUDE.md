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
