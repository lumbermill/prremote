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
- CI（`.github/workflows/ci.yml`）は既に mruby 4.0.0 固定で linux mrbc をビルドして
  ランタイムビルドに使っている。このジョブを matrix 化（macos runner は public リポジトリなら
  無料）してリリース資産に足せば、この項目の大半は同じワークフローで済む

## 品質保証: 対象ボードが増えた分をどう守るか（次にやる）

対象は pico / picow / pico2 / esp32（M5GO・M5StickC PLUS 共用）/ esp32c6 の 5 イメージ・6 ボード。
「毎コミット全機種を手で実機確認」は続かないので、**安い層ほど頻繁に・広く**、実機は無人化して回す 3 層構成にする。

0.4.3 で実際に起きたこと（この計画の根拠）:

- `bindings_esp32c6.c` だけ変更漏れ → C6 で `I2C#scan` が NoMethodError。ビルドもテストも通り、XIAO 実機で初めて発覚。
  **実機なしで機械的に検出できた種類の不具合**。
- Pico で bit-bang プローブ後に同じ `I2C` インスタンスの read/write が失敗 → I2C デバイス付きの実機で、
  インスタンス再利用まで試して初めて発覚。
- ST7032 LCD がリードプローブで SDA を握る → 実デバイスがないと再現しない。リセットしても残るので電源断が要る。

### 層 1: 実機なし・毎コミット（CI）

- ✅ **バインディング整合テスト**（`test/binding_parity_test.rb`、済み）: `runtime/src/*_wrap.rb` が呼ぶ `_xxx` を抽出し、
  `bindings.c` / `bindings_esp32.c` / `bindings_esp32c6.c`（＋`bindings_cyw43.c` 等）の `mrbc_define_method` 登録と突き合わせる
  ホスト側 Minitest。ボード非対応は `c_not_on_esp32` のような明示スタブ登録を要求し、「登録漏れ」と「意図的な非対応」を区別する。
  0.4.3 の C6 漏れはこれで防げた（`42cf86d` 時点の `bindings_esp32c6.c` で `_i2c_probe` 未登録として FAIL することを確認済み）。
  ビルドごとの構成（ラッパー × C ソース）はテスト内の表で持ち、CMake とのずれも同テストで検出する。
- **Ruby 層のフェイクバス・テスト**: `test/hw_wrap_i2c_test.rb` の方式（`hw_wrap.rb` を CRuby に読み込み、C 関数を偽物に差し替え）を
  GPIO / SPI / PWM / LCD の Ruby 側ロジックにも広げる。
- **成果物の中身検査**: CI のビルド後、各イメージに VERSION 文字列と新規シンボルが入っているかを grep で確認（今回手元でやった確認の自動化）。

### 層 2: 常設ベンチで実機を無人実行（Raspberry Pi + 全ボード挿しっぱなし）

常時稼働の Raspberry Pi 4 に全ボードを USB で挿したままにし、**Pi 側から取りに行く pull 型**で `rake smoke[board]` の auto 項目を無人実行する。
public リポジトリでの self-hosted runner は GitHub 非推奨（fork PR からの任意コード実行）なので、
GitHub → Pi の inbound 信頼を作らないことが設計の軸。Pi 4 で十分（ビルドはしない）。

- **実行タイミングを「公開後」から「タグ前」に前倒し**: CI は main への push ごとに全ボードのランタイムを artifact（7 日保持）にしている。
  Pi は main ブランチの成功 run の artifact だけを取りに行き（main に push できるのはメンテナのみなので、fork PR の成果物は対象外にする）、
  焼いてスモークを回す。結果が緑ならタグを打つ。公開後のスモーク（published `runtime-X.Y.Z` + gem）も従来どおり残す。
- **USB まわり**: セルフパワーで**ポート個別に電源を切れる USB ハブ**（`uhubctl` 対応品）を使う。
  固まったデバイス（0.4.3 の LCD のように MCU のリセットでは戻らないもの）や USB の wedge を、人手の抜き差しなしで電源断して復旧できる。
  ポートは `/dev/serial/by-id/` でボードに固定対応させる。
- **書き込みはすべて無人化済み**: esp32 = EspFlasher の自動リセット、esp32c6 = `--before usb-reset`、
  pico 系 = 0.4.3 の 1200bps タッチ（`install` が自動で BOOTSEL に入れる。ランタイムが固まっている時だけハブの電源断＋手動 BOOTSEL が要る）。
- **検証用の固定配線（治具）を各ボードに付ける**ことで、今は目視（eyeball）の項目を auto にする:
  - I2C: ADT7410（0x48）＋ ST7032 LCD（0x3E）を全ボードで同じ構成に。`scan == [0x3e, 0x48]`、温度が妥当範囲、
    `scan` 後に同一インスタンスで read/write、旧方式で LCD を固めて `I2C.new` で復旧、までを assert。
  - GPIO 出力→別 GPIO 入力、PWM→RC フィルタ→ADC、SPI MOSI→MISO のループバック配線。
  - ソケットは Pi 自身に UDP/TCP エコーサーバを常駐、WiFi クレデンシャルは Pi 上の git 管理外（`wk/` 方式）。
- **どの機種を回すか**: リリース前は全ボード。開発中は変更ファイルから絞る:
  `bindings.c` / `platform_pico.c` → pico 系、`esp32/main/*` → M5GO（＋M5StickC PLUS）、`esp32c6/main/*` → XIAO、
  `runtime/src/*_wrap.rb` / `runtime.c` → 全ボード。
- **結果通知**: `gh issue create`（fine-grained PAT、issues:write のみ）またはログ＋メール。draft には反応しない。
- **未確認ボードの解消**: pico2 は実機がないため 🧪 のまま。ベンチに 1 台加えれば SUPPORT.md の 🧪 を消せる。

### 層 3: 人手（リリース前に数分）

LCD の表示内容・LED・ボタン・ブザー・IR など、シリアル出力で判定できないものだけ。`rake smoke` の `[ ]` 項目として残す。

### 着手順

1. ~~バインディング整合テスト~~（済み）
2. I2C 治具を全ボードに付けて `rake smoke` の I2C を auto 化（手元の Mac から実行できる段階で効果が出る）
3. Pi ＋ uhubctl ハブのベンチ構築と、main artifact の pull → 焼き → スモークの無人化

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
