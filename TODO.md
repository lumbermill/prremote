# prremote TODO

## コマンド実装

- [x] `install` — UF2ダウンロード（初回）＋キャッシュ＋BOOTSEL書き込み
- [x] `list`    — シリアルデバイス一覧
- [x] `version` — gemバージョン＋デバイスランタイムバージョン（ベストエフォート）
- [x] `deploy FILE` — `.rb` → `.mrb` コンパイル＋シリアル送信＋RUNNING/DONE待機
- [ ] `eval EXPR`   — ワンライナーを一時ファイルに書いて deploy と同じ流れ
- [ ] `reset`       — シリアルに `0x03` を送信してデバイスをリブート
- [ ] `watch FILE`  — ファイル変更監視 → auto deploy + reset

## ランタイム (runtime/)

- [ ] version コマンドのためのプローブ対応: デバイスが実行中でも `0x03` 以外の特定バイトに READY を返す仕組み（現状はデバイスアイドル時のみ取得可能）

## mrbc の扱い

- 現状: PATH上の `mrbc` を使う（ユーザーが `brew install mruby` 等で用意）
- [ ] **将来: プラットフォームgem として mrbc バイナリを同梱**
  - `rake-compiler-dock` でmrubyをクロスコンパイルし、プラットフォーム別gemに焼き込む
  - 対象: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`
  - 参考: nokogiri / grpc のgemspec・CI設定
  - これにより `gem install prremote` だけで mrbc が手に入る

## 旧コードの整理

- [ ] 旧コマンド群（`ls` / `put` / `get` / `run` / `rm` / `mkdir` / `repl` / `irb` / `open`）を削除
- [ ] `Connection` クラスを新プロトコル用に書き直し（または削除）
- [ ] 旧コマンドに対応するテストを削除し、新コマンドのテストを追加

## パッケージング・CI

- [ ] RuboCop lint パス確認
- [ ] CHANGELOG.md
- [ ] GitHub Actions CI を新コマンド構成に合わせて更新
