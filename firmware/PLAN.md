# firmware ビルド計画

## 目標

`prremote install` で書き込める Pico / Pico W 向け UF2 を作る。
UF2 を書き込んだだけで prremote-agent のプロトコルが動くこと。

---

## アーキテクチャ方針

**agent は /home/app.rb ではない。ファームウェアバイナリに焼き込む。**

prremote の用途はユーザーの `app.rb` をデバイスに転送することなので、
agent が `/home/app.rb` を占有してはいけない。

```
UF2 バイナリ
  ├── mruby/c VM（libmruby.a）
  ├── 必要な picogem（uart, gpio, machine, littlefs, dir, file）
  └── prremote-agent（agent.rb → picorbc でコンパイル → C配列として焼き込み）

LittleFS（ファイルシステム領域）
  └── /home/app.rb  ← ユーザーが自由に書き込む（agent とは無関係）
```

### 起動フロー（MicroPython パターンを踏襲）

MicroPython は「常時並列エージェント」を持たない。
代わりに **「割り込みシグナル → コマンドモード → リセットして再開」** という直列アクセスで解決している。
prremote も同じパターンを採用する。

タイムアウト方式は採用しない。代わりに MicroPython と同じ「即時起動 + 割り込み」パターン。

```
電源 ON
  → 約200ms だけ 0x03 (Ctrl+C) を待つ（ホストが reset 直後に送るため）
      0x03 が届いた → agent ループへ（ファイル転送などを受け付ける）
      届かなかった  → /home/app.rb が存在すれば即座に実行
                      存在しなければ agent ループへ
  → app.rb 実行中に 0x03 を受信 → app.rb を中断 → agent ループに戻る
  → RESET コマンド受信 → Machine.reset → 先頭に戻る
```

```
通常の開発サイクル（初回・app.rb なし）:
  prremote put app.rb   → 200ms 待機中 or agent ループ中に PUT コマンドで転送
  prremote reset        → RESET → 再起動 → 200ms 後 app.rb 即実行

app.rb 実行中に更新:
  prremote put app.rb   → ホストが 0x03 を送信 → agent モードへ
                        → PUT でファイル転送 → RESET → 再起動

（ホスト側 prremote コマンドは常に通信前に 0x03 を送る責務を持つ）
```

---

## ビルドパイプラインの全体像（ソース調査済み）

picoruby リポジトリを実際に読んで確認した内容。

### 2ステージビルド

```
Stage 1: libmruby.a のビルド（picoruby の Rake）
  MRUBY_CONFIG=build_config/prremote-picoruby-pico.rb rake
  → build/prremote-picoruby-pico/lib/libmruby.a  （ARM クロスコンパイル済み）
  → bin/picorbc  （ホスト用 Ruby→バイトコードコンパイラ）

Stage 2: UF2 のビルド（cmake）
  cmake -S mrbgems/picoruby-prremote/cmake -B build/prremote/pico/prod \
    -D PICORUBY_ROOT=... \
    -D PICO_BOARD=pico \
    -D PICORB_VM_MRUBY=1 ...
  cmake --build build/prremote/pico/prod
  → build/prremote/pico/prod/prremote-*.uf2
```

### CMake 内での agent.rb コンパイル（確認済みパターン）

`mrbgems/picoruby-r2p2/cmake/CMakeLists.txt` の実装から確認:

```cmake
set(PICORBC ${PICORUBY_ROOT}/bin/picorbc)
set(RUBY_FILES main_task)

foreach(rb ${RUBY_FILES})
  add_custom_target(${rb}
    COMMAND
      ${PICORBC} -B${rb} -o${CMAKE_BINARY_DIR}/mrb/${rb}.c mrblib/${rb}.rb
  )
endforeach(rb)
```

生成される `mrb/main_task.c`:
```c
const uint8_t main_task[] = { 0x52, 0x49, 0x54, 0x45, ... };
```

### main.c での実行（確認済みパターン）

`mrbgems/picoruby-r2p2/ports/rp2040/main.c` の実装から確認:

```c
#include "main_task.c"   // picorbc が生成した C 配列を include

// mruby/c (PICORB_VM_MRUBYC) の場合:
mrbc_init(heap_pool, HEAP_SIZE);
mrbc_tcb *tcb = mrbc_create_task(main_task, 0);
mrbc_set_task_name(tcb, "main_task");
picoruby_init_require(&tcb->vm);
mrbc_run();

// mruby (PICORB_VM_MRUBY) の場合:
mrb_read_irep(mrb, main_task);
mrc_create_task(...);
mrb_task_run(mrb);
```

**ポイント**: コンパイラは `picorbc`（picoruby 独自）。mruby の `mrbc` ではない。

---

## 作成が必要なファイル

### 1. build_config（ARM クロスコンパイル設定）

`firmware/picoruby/build_config/prremote-picoruby-pico.rb`

RP2040 は cortex-m0plus。既存の `r2p2-picoruby-pico2.rb`（cortex-m33）を元に調整:
- `-mcpu=cortex-m0plus`（m33 → m0plus）
- `-mslow-flash-data` を削除（RP2040 非対応フラグ）
- `MRB_USE_CUSTOM_RO_DATA_P` / `MRB_LINK_TIME_RO_DATA_P` は要確認
- gembox は最小限（shell / keyboard 不要）

`firmware/picoruby/build_config/prremote-picoruby-pico_w.rb`
- 上記に加え `picoruby-cyw43` を追加

### 2. prremote gem（`mrbgems/picoruby-prremote/`）

```
picoruby-prremote/
  mrblib/
    main_task.rb        ← agent.rb の内容（agent ループ）
  cmake/
    CMakeLists.txt      ← picoruby-r2p2 の cmake を元に最小化
    pico_sdk_import.cmake
    pico_extras_import.cmake
  ports/
    rp2040/
      main.c            ← picoruby-r2p2 の main.c をそのまま流用可能
  mrbgem.rake
```

### 3. Rake タスク

`firmware/picoruby/tasks/picoruby/prremote.rake`

既存の `r2p2.rake` を参考に:
- `prremote:pico:prod` / `prremote:pico:debug`
- `prremote:pico_w:prod` / `prremote:pico_w:debug`

---

## 未解決事項

| 項目 | 内容 | 対処方針 |
|------|------|---------|
| BOOT_WAIT_MS の値 | 何ms待つか | 200ms。`prremote reset` がリセット後すぐ 0x03 を送れる十分な長さ |
| app.rb の実行方法 | PicoRuby で別ファイルを `load` できるか | `require` / `load` の有無を確認。できなければ `File.read` + `eval` |
| Ctrl+C 割り込みの実装 | app.rb 実行中に 0x03 を検知する方法 | mruby/c のマルチタスクで agent を常時起動し続けるか、app.rb 自体に割り込みチェックを埋め込む必要がある |
| RP2040 用 build_config | m0plus フラグの正確なセット | `prk_firmware-cortex-m0plus.rb` を参考に作成 |
| VM 選択 | mruby か mruby/c か | R2P2 は両対応。初期は mruby（PICORB_VM_MRUBY）推奨（R2P2 のデフォルト） |
| `picoruby-eval` gem | EVAL コマンドで使えるか | mrbgems に `picoruby-eval` と `picoruby-sandbox` が存在。確認要 |
| `File.delete` | PicoRuby に存在するか | ソース確認。なければ `File.unlink` または C 拡張 |
| pico-sdk submodule | pico-sdk 2.2.0 が必要 | `r2p2:setup` タスクで初期化済みのものを使う |

---

## ビルド手順（暫定）

```bash
cd firmware/picoruby

# 1. pico-sdk サブモジュール初期化（初回のみ）
rake r2p2:setup

# 2. ホスト向けビルド（picorbc を生成）
MRUBY_CONFIG=build_config/default.rb rake

# 3. prremote 用 libmruby.a ビルド（ARM）
MRUBY_CONFIG=build_config/prremote-picoruby-pico.rb PICORB_BOARD=pico rake

# 4. cmake で UF2 生成
rake prremote:pico:prod

# 5. BOOTSEL モードで Pico を接続し UF2 を書き込む
cp build/prremote/pico/prod/prremote-*.uf2 /Volumes/RPI-RP2/
```

---

## 参考にしたソース

| ファイル | 用途 |
|---------|------|
| `mrbgems/picoruby-r2p2/ports/rp2040/main.c` | main() の実装パターン |
| `mrbgems/picoruby-r2p2/cmake/CMakeLists.txt` | cmake + picorbc の使い方 |
| `mrbgems/picoruby-r2p2/mrblib/main_task.rb` | Ruby エントリポイントの役割 |
| `build_config/r2p2-picoruby-pico2.rb` | cortex-m33 の build_config 書式 |
| `build_config/prk_firmware-cortex-m0plus.rb` | cortex-m0plus の build_config 書式 |
| `tasks/picoruby/r2p2.rake` | Rake タスクの書き方 |
