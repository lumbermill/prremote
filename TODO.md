# prremote TODO

## コマンド実装

- [x] `install`      — UF2ダウンロード（初回）＋キャッシュ＋BOOTSEL書き込み
- [x] `list`         — シリアルデバイス一覧
- [x] `version`      — gemバージョン＋デバイスランタイムバージョン（ベストエフォート）
- [x] `run FILE`     — `.rb` → `.mrb` コンパイル＋シリアル送信＋RUNNING/DONE待機（即時実行・保存なし）
- [x] `deploy FILE`  — `.rb` → `.mrb` コンパイル＋フラッシュ書き込み（次回電源投入時に自動実行）
- [ ] `undeploy`     — フラッシュのスクリプトを消去して自動起動を無効化
- [ ] `eval EXPR`    — ワンライナーを一時ファイルに書いて run と同じ流れ
- [ ] `reset`        — シリアルに `0x03` を送信してデバイスをリブート
- [ ] `watch FILE`   — ファイル変更監視 → auto run + reset

## ランタイム (runtime/)

- [ ] **ファームウェア再ビルド・再書き込みが必要**: `deploy` コマンドの対応（flash 書き込み + `DPLY` プロトコル）はランタイム側の変更を含む。現行デバイスには `prremote install` で新ファームを焼き直す必要あり。
- [ ] version コマンドのためのプローブ対応: デバイスが実行中でも `0x03` 以外の特定バイトに READY を返す仕組み（現状はデバイスアイドル時のみ取得可能）
- [ ] 自動起動パスの確認中だった件: `runtime/src/runtime.c` で `flash_has_script()` → 起動時実行を実装済み。フラッシュ末尾 64KB (`FLASH_STORAGE_OFFSET = PICO_FLASH_SIZE_BYTES - 64KB`) に "PRRD" マジック＋サイズ＋.mrb を格納。

## mrbc の扱い

- [ ] 利用するmrbcのパス、バージョンを version コマンドで表示
- 現状: PATH上の `mrbc` を使う（ユーザーが `brew install mruby` 等で用意）
- [ ] **将来: プラットフォームgem として mrbc バイナリを同梱**
  - `rake-compiler-dock` でmrubyをクロスコンパイルし、プラットフォーム別gemに焼き込む
  - 対象: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`
  - 参考: nokogiri / grpc のgemspec・CI設定
  - これにより `gem install prremote` だけで mrbc が手に入る

## 旧コードの整理

- [ ] 旧コマンド群（`ls` / `put` / `get` / `run` / `rm` / `mkdir` / `repl` / `irb` / `open`）を削除
- [ ] 旧実装でしか使わない箇所を削除
- [ ] `Connection` クラスを新プロトコル用に書き直し（または削除）
- [ ] 旧コマンドに対応するテストを削除し、新コマンドのテストを追加

## パッケージング・CI

- [ ] RuboCop lint パス確認
- [ ] CHANGELOG.md
- [ ] GitHub Actions CI を新コマンド構成に合わせて更新
