# PLAN 将来計画

未着手・検討中の項目のみを記す。
**対応済みのボード／機能の一覧と動作確認手順は [docs/SUPPORT.md](docs/SUPPORT.md)** に移動した。
実装の経緯は CHANGELOG.md / git log を参照。

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

## 対応ボードの拡張候補

実装済み（pico / picow / pico2 / esp32 / esp32c6）は [docs/SUPPORT.md](docs/SUPPORT.md) 参照。今後の候補:

| ターゲット | 追加コスト | 判断 |
|---|---|---|
| ESP32-S3 / C3 | sdkconfig の target 切り替え + ピンデフォルト調整（ネイティブ USB CDC あり） | 需要を見て判断 |
| STM32 | 約 2〜3 週間（HAL 細分化が多い） | 優先度低 |
| nRF52 / Zephyr | 約 2 週間（mruby/c に Zephyr HAL あり） | 優先度低 |

現実的には維持コストの観点から、ここから先はエコシステムが分散してテスト・リリース管理の負担が重くなる。

## LCD 図形描画（draw_line/circle/ellipse）の実機目視（残）

C 実装の `LCD#draw_line` / `#draw_circle` / `#draw_ellipse` は 0.3.0 でビルド確認済みだが、
実パネルでの見た目（斜め線の連続性・円/楕円の輪郭欠け・fill のベタ塗り）は未目視。
検証用スクリプトは [wk/lcd_shapes_c6.rb](../wk/lcd_shapes_c6.rb)（MSP2807 を lcd_hello.rb と同じ配線で接続）。
M5GO 用は [examples/m5go/lcd_shapes.rb](../examples/m5go/lcd_shapes.rb)。
（XIAO ESP32C6 の pin_check / pwm / spi_loopback / I2C デフォルト / WiFi・NTP は 0.3.0 で実機検証済み。）

余裕があれば PWM の外部 LED 版（明るさ）・サーボ版（50Hz / duty で角度）、
SPI の実デバイス版（フラッシュ / SD の JEDEC ID 読み出し）サンプルも追加検討。

## classic esp32（M5GO）TCP/UDPSocket の実機検証（残）

esp32c6 と同じ socket 配線（`HAS_SOCKET` / `HAS_UDP_SOCKET`、`MAX_VM_COUNT=8`、
lwipopts shadow 対策）を `esp32/main/CMakeLists.txt` と `bindings_esp32.c` に展開済み。
ビルド確認のみ・M5GO 実機は未検証。検証は WiFi 接続後に
[examples/m5go/socket_udp.rb](examples/m5go/socket_udp.rb)（クレデンシャルは `wk/` コピーで）を
エコーサーバ相手に流し、UDP 往復と TCPSocket（`wk/tcp_probe.rb` 相当）を確認する。
確認できたら [docs/SUPPORT.md](docs/SUPPORT.md) の 🧪 を ✅ に上げる。

## ESP32 LCD の向き自動補正（任意・優先度低）

パネル種別ごとの向き補正は現状 `LCD.new(madctl:)` 手動指定で吸収している（ILI9341/MSP2807 は `madctl: 0xE8`）。
ILI9341 を既定で正しい向きにする C 層のパネル種別フラグ化は、必要になれば検討（現状は手動指定で足りている）。

## M5Stack Core2 対応（将来）

同じ esp32 ランタイムで射程内。差分は LCD ピン（CS=5, DC=15, RST なし）と
**AXP192 電源初期化**（LDO2/DCDC3/GPIO4 を叩かないと画面が点かない）の追加のみ。
タッチ（FT6336U、I2C 0x38）は I2C バインディングで Ruby から読める。

## 画像表示（`draw_image`）の実装方法検討

現状の `examples/tools/img2rle.rb` は RGB565 RLE をバイナリ文字列定数として `.rb` ファイルに埋め込み、
`String#getbyte` で走査して `fill_rect` を呼ぶアプローチ。

**懸念点:**

- RLE データが大きいと mrb バッファを圧迫する（現状 64 KB に拡張して対応しているが綱渡り）
- Ruby バイトコードへの埋め込みが本来の用途外
- 単色域が少ない写真では圧縮率が低く、バッファに入りきらない可能性がある

**検討すべき代替案:**

- **deploy 経由でバイナリを Flash に置く**: `prremote deploy` で `.bin` をパーティションに書き込み、
  デバイス側で Flash から直接読む。mrb バッファを消費しない。Ruby API は `LCD.draw_image(name)` 程度で済む。
- **SPIFFS / LittleFS 上のファイル**: ESP-IDF の VFS でファイルとして扱い、
  ストリーム読み込みで描画。汎用性が高いが実装コストも大きい。
- **現行 RLE + デバイス側定数参照（現状維持）**: シンプルだが大きな画像には不向き。

→ **方針未定。実装前に上記トレードオフを再評価する。**
