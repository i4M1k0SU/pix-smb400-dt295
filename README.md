# PIX-SMB400-DT295

PIX-SMB400 の Mirakurun に、PIX-DT295 をチューナーとして追加するスクリプト

PIX-SMB400 (Android 8、Linux 4.9 の armv7l) の USB ポートに PIX-DT295 を接続し、本体で動く Mirakurun (BS4K 版) で本体のチューナーと並べて使用する。
PIX-DT295 は [smpn2/pix-dt295](https://github.com/smpn2/pix-dt295) の `dt295` で動作させる。

個体は raw-TS モードで動かし、スクランブルの解除は本体のチューナーと同じく本体の `b21dec` (本体の ACAS チップで MULTI2 の鍵を得る) が行う。
そのため、ファームウェアも、PIX-DT295 の B-CAS カードも不要。

## 前提

- PIX-SMB400 に [nanamitm/pix-smb400-mirakurun](https://github.com/nanamitm/pix-smb400-mirakurun) の導入が済んでいること
- USB ハブ経由で PIX-DT295 が接続されていること
  - USB ブート用の USB メモリも接続する必要があるため

## 導入

### 1. ファイルを配置する

- `/data/local/tmp/dt295/`
  - `dt295`: ARMv7 版の実行ファイル
  - `start_dt295.sh`
  - `dt295-tuner.sh`
  - `dt295.conf`
  - `90-dt295.sh`

```bash
ln -s /data/local/tmp/dt295/90-dt295.sh /data/local/tmp/mirakurun-root/etcprofile.d/90-dt295.sh
chmod 755 /data/local/tmp/dt295/dt295 /data/local/tmp/dt295/start_dt295.sh data/local/tmp/dt295/dt295-tuner.sh
```

### 2. `/data/local/tmp/dt295/dt295.conf` を編集

`[unit ...]` を、接続している個体のシリアル番号に変更する (個体ごとに 1 つ、全て `raw-ts = true` とする)

```bash
# シリアル番号の確認
/data/local/tmp/dt295/dt295 list
```

### 3. Mirakurun の `tuners.yml` の本体のチューナー (`SMB400`) の後ろに、個体ごとに追加し Mirakurun を再起動する

```yaml
- name: DT295-AB12345678
  types:
    - GR
    - BS
    - CS
  command: /data/local/tmp/dt295/dt295-tuner.sh AB12345678 <channel>
  isDisabled: false
```

- nanamitm/pix-smb400-mirakurun リポジトリの `make push-config` は `tuners.yml` を上書きするので、必要があればそちらの `config/tuners.yml` にも追加しておく
- `dt295-tuner.sh` は本体のチューナー (`smb400-tuner.sh`) と同じチャンネル名を受け取り、`dt295 tune` の引数に変換するので、`channels.yml` はそのまま使用できる
  - 地デジ `13`-`62` は UHF の周波数、BS `BSxx_y` は IF と TSID、CS `NDxx` は IF に変換する
  - BS の TSID は本体と同じ表 (`/data/local/tmp/bs_tsid.conf`) から引く
- 出力は復号済みの TS で、全サービスを含む
- チューナーに `decoder` は設定しない


## 更新方法

- `dt295` を更新するときは、`start_dt295.sh stop` で止めてから push する
- `dt295-tuner.sh` は、別の名前で push して `chmod 755` してから `mv` で置き換える
  - 実行権の無い間に Mirakurun がチューナーのコマンドを 3 回起動できないと、そのチューナーを故障扱い (`isFault`) にし、Mirakurun を再起動するまで使用しなくなるため


## 仕組み

- `dt295 serve` は chroot の外 (Android 側) で動作する
- Mirakurun は chroot の中でチューナーのコマンド `dt295-tuner.sh` を呼び出す
  - `dt295-tuner.sh` は `dt295 tune` の TS を、`chroot /proc/1/root` で Android 側の `b21dec` を通し、復号済みの TS を出力する
  - `dt295 tune` は、chroot に bind mount された `/data/local/tmp` の下のソケットに接続する
- 起動時に、Mirakurun を起動する Alpine のログインシェルが `/etc/profile.d/90-dt295.sh` を読み、`chroot /proc/1/root` で Android 側に戻って `start_dt295.sh` を実行する
  - chroot のログインシェルに入るたびにも実行されるが、`dt295 serve` が動いていれば何もしない
  - `start_dt295.sh stop` で止めた後であっても、ログインシェルに入ると起動し直す

| ファイル | 内容 |
|---|---|
| `dt295/start_dt295.sh` | `dt295 serve` の起動と停止 (`start`、`stop`、`status`) |
| `dt295/dt295-tuner.sh` | Mirakurun のチューナーのコマンド (`dt295 tune` + 本体の `b21dec`) |
| `dt295/dt295.conf` | `dt295 serve` の設定のサンプル |
| `dt295/90-dt295.sh` | 電源を入れたときの `dt295 serve` の起動 (chroot の `/etc/profile.d/` からリンクする) |


## ライセンス

[MIT LICENSE](LICENSE)
