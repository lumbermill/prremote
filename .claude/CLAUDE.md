# prremote — 開発メモ

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
# ルートで
bundle exec rake gem            # pkg/prremote-X.X.X.gem をビルド
gem push pkg/prremote-X.X.X.gem  # RubyGems.org に push
git tag vX.X.X && git push origin vX.X.X
```

`RUNTIME_VERSION` を上げるときは、先にランタイムをリリースしてから gem をリリースする。
