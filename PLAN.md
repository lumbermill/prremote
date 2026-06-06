# PLAN 将来計画

## TCPSocket.gets タイムアウト

現状の `gets` は `readpartial(1)` を 1 バイトずつ呼ぶループで、C 層に 60 秒 per-call タイムアウトがある。
サーバーが改行を送らずデータを drip-feed し続ける場合は永久ブロックし得る。

対処するなら `read_nonblock` + `ready?` + 経過時間チェックの自前ポーリングループで実装する。
mruby/c には `Timeout` モジュールもスレッドもないため Ruby 層で対処するしかない。
（2026-06-06 時点: 様子見）

## mrbc の自動取得・キャッシュ

現状は mrbc をユーザー環境に依存しているが、初回セットアップの障壁になっている。
ランタイム（`.uf2`）と同様に、実行時に GitHub Releases からダウンロードしてキャッシュする方式を採用する。

- `RUNTIME_VERSION` に対応する mrbc バイナリをランタイムと同じリリースタグに同梱する
- 対象プラットフォーム: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`, `aarch64-linux`
- Linux は glibc 互換性のため Ubuntu 20.04 系でビルドする（または musl で完全静的リンク）
- キャッシュ済みであれば再ダウンロードしない（UF2 と同じ挙動）
- `$MRBC` 環境変数による上書きは引き続き有効

## Pico / Pico W の判別サポート

BOOTSEL モードでは USB PID・ボリューム名・`INFO_UF2.TXT` がすべて同一のため、ソフトウェアによる自動判別は不可。ユーザーが自分で判断できるよう案内する方向で検討する。

候補:

- **ドキュメントページ（ウェブ）**: 外観写真付きで見分け方を解説。Pico W はボード裏面に "Pico W" のシルク印刷があり、表面に WiFi アンテナのパターン（白いジグザグ線）がある
- **`prremote install` の対話プロンプト**: ボード未指定時に "Pico W ですか？ [y/N]" と聞く。`--board` オプションと併用

## ESP32 対応

### 現状把握

mruby/c には既に `hal/esp32/hal.c` が存在する。mruby/c 層は対応済みのため、必要な作業は prremote 独自の部分に絞られる。

runtime のソース構成（`runtime/src/`）:

| ファイル | 内容 | ESP32 対応コスト |
|---|---|---|
| `runtime.c` | シリアルプロトコル本体（RUN/ERSE/DPLY 等） | 小: stdio 初期化だけ変わる |
| `bindings.c` | GPIO / ADC / PWM / I2C / SPI の C バインディング | 大: ESP-IDF API に全面書き直し |
| `bindings_cyw43.c` | WiFi（CYW43 専用） | 大: ESP-IDF WiFi スタックに置き換え |
| `CMakeLists.txt` + `pico_sdk_import.cmake` | Pico SDK ビルド定義 | 大: ESP-IDF のコンポーネント構成に変更 |

### ボード・バリアント

| バリアント | アーキテクチャ | ネイティブ USB CDC | 備考 |
|---|---|---|---|
| ESP32 (classic) | Xtensa LX6 | なし（USB-UART ブリッジ経由） | 最もポピュラー |
| ESP32-S3 | Xtensa LX7 | あり | RAM 多め、高性能 |
| ESP32-C3 / C6 | RISC-V | あり | 小型・省電力 |

初期対応は **ESP32 classic + ESP32-S3** が現実的。USB CDC なし（classic）でも prremote のシリアルプロトコルは UART 上でそのまま動く。

### deploy/undeploy の課題

Pico では独自フラッシュプロトコルで `.mrb` を直接書き込んでいるが、ESP32 では NVS パーティションまたは SPIFFS/LittleFS パーティションへの書き込みになる。プロトコルレベルの変更は不要だが、ランタイム側のフラッシュ操作部分は設計し直しが必要。

### 工数試算

| 作業 | 目安 |
|---|---|
| ESP-IDF ビルド環境・CMake 構成 | 1〜2 日 |
| `runtime.c` の stdio 初期化移植 | 0.5 日 |
| フラッシュ（deploy/undeploy）設計・実装 | 2〜3 日 |
| ハードウェアバインディング（GPIO/ADC/PWM/I2C/SPI/WiFi） | 3〜5 日 |
| 実機テスト・デバッグ | 2〜3 日 |
| **合計** | **約 2 週間** |

### 対応ボード数の現実的な上限

| ターゲット | 追加コスト | 判断 |
|---|---|---|
| RP2350（Pico 2 / Pico 2W） | 極小（同じ Pico SDK、CMake ターゲット追加のみ） | やる価値あり |
| ESP32 | 約 2 週間 | ユーザー数が多く費用対効果あり |
| STM32 | 約 2〜3 週間（HAL 細分化が多い） | 優先度低 |
| nRF52 / Zephyr | 約 2 週間（mruby/c に Zephyr HAL あり） | 優先度低 |

現実的には **RP2350 + ESP32 まで** が維持コストとのバランスが取れる上限と思われる。それ以上はエコシステムが分散してテスト・リリース管理の負担が重くなる。

## M5Stack Core2 対応

ESP32 (classic) ベースのため、**ESP32 対応が完了すれば自動的に射程に入る**。実機（Core2）が手元にあるため、動作確認・デバッグの優先ターゲットとして活用できる。

### Core2 のハードウェア仕様

| 項目 | 内容 |
|---|---|
| チップ | ESP32 (Xtensa LX6) |
| SRAM | 520 KB + 16 MB PSRAM |
| Flash | 4 MB + 16 MB（外部） |
| LCD | ILI9342C、2インチ、320×240、SPI 接続 |
| タッチ | FT6336U（静電容量式） |
| 電源管理 | AXP192 |
| IMU | MPU6886 |

### LCD 対応

LCD（ILI9342C）は SPI 接続のため、SPI バインディングが整えば mruby/c 側からコントロールできる。やりたい機能の方向性：

- `LCD` クラスを Ruby 層に追加
- 文字・図形描画（フォント内蔵または外部フォント）
- `deploy` したスクリプトから画面出力できる

ILI934x 系は既存の OSS ドライバ（C 実装）が豊富なため、ESP-IDF コンポーネントとして取り込む方針が現実的。

### 優先順位

ESP32 基本対応 → SPI バインディング → LCD ドライバ組み込み → `LCD` Ruby クラス の順。
