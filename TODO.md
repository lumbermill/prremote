# prremote TODO

## コマンド実装

- [x] `install`      — UF2ダウンロード（初回）＋キャッシュ＋BOOTSEL書き込み
- [x] `list`         — シリアルデバイス一覧
- [x] `version`      — prremote / mrbc（パス＋バージョン）/ デバイスランタイム（ベストエフォート）
- [x] `run FILE`     — `.rb` → `.mrb` コンパイル＋シリアル送信＋RUNNING/DONE待機（即時実行・保存なし）
- [x] `deploy FILE`  — `.rb` → `.mrb` コンパイル＋フラッシュ書き込み（次回電源投入時に自動実行）
- [x] `undeploy`     — フラッシュのスクリプトを消去して自動起動を無効化（`ERSE` プロトコル、ランタイム変更含む）
- [x] `eval EXPR`    — ワンライナーを一時ファイルに書いて run と同じ流れ
- [x] `reset`        — シリアルに `0x03` を送信してデバイスをリブート
- [x] `watch FILE`   — ファイル変更監視 → auto run（polling、0.5秒間隔）

## ランタイム (runtime/)

- [ ] **ファームウェア再ビルド・再書き込みが必要**: `undeploy`（`ERSE`）の追加はランタイム変更を含む。現行デバイスには `prremote install` で新ファームを焼き直す必要あり。
- [ ] version プローブ対応: デバイスが実行中でも特定バイトに `READY` を返す仕組み（現状はアイドル時のみ取得可能）

## mrbc の扱い

- [x] 利用する mrbc のパス・バージョンを version コマンドで表示（`Mrbc` モジュールに共通化、`$MRBC` 環境変数で上書き可）
- [ ] **将来: プラットフォームgem として mrbc バイナリを同梱**
  - `rake-compiler-dock` でmrubyをクロスコンパイルし、プラットフォーム別gemに焼き込む
  - 対象: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`
  - 参考: nokogiri / grpc のgemspec・CI設定

## 旧コードの整理

- [x] 旧コマンド群（`ls` / `put` / `get` / `run` / `rm` / `mkdir` / `repl` / `irb` / `open`）を削除
- [x] 旧実装でしか使わない箇所を削除
- [x] `Connection` クラスを削除（新プロトコルでは各コマンドが Serial を直接使用）
- [x] 新コマンドのテストを追加（`run` / `deploy` / `eval` / `undeploy`）

## パッケージング・CI

- [x] RuboCop lint パス確認（22 files, no offenses）
- [x] CHANGELOG.md
- [x] GitHub Actions CI を新コマンド構成に合わせて更新
