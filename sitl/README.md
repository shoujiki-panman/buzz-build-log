# SITL環境構築・再現手順

ArduPilot SITL（Software In The Loop）をMac上で動かし、シミュレータ内のCopterが
ARM→離陸コマンドに反応するまでの手順。**2026-07-08にM5/32GB Mac（macOS 26.4）で構築・動作確認済み。**

- ArduPilot: `master` ブランチ `698a86fe2b`（ArduPilot-4.6.0-beta1-7396）
- Python: 3.10.18（pyenv、公式スクリプトが導入）／ MAVProxy: 1.8.74
- クローン先: `~/ardupilot`（このリポジトリの外。約3GB）

## 1. セットアップ（公式手順）

公式: https://ardupilot.org/dev/docs/building-setup-mac.html

```bash
# 前提: Xcode Command Line Tools と Homebrew が入っていること
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git ~/ardupilot
cd ~/ardupilot
./Tools/environment_install/install-prereqs-mac.sh -y
```

スクリプトが `~/.zshrc` にpyenv等のPATH設定を追記する。実行後は**新しいターミナルを開く**か
`source ~/.zshrc` して反映する。

### この環境で踏んだ罠（2026-07-08）

1. **`.zshrc` のbun補完でスクリプトが途中死する**
   スクリプトはbashで動き、途中で `~/.zshrc` をsourceする。zsh専用のbun補完
   （`source ~/.bun/_bun`）がbashでsyntax errorになり、`set -e` で静かに止まった
   （pyenvインストール直後、pipパッケージ導入前）。
   → 対処: pyenvをPATHに載せて再実行すると、問題のsource行を通らず完走する。
   ```bash
   export PYENV_ROOT="$HOME/.pyenv"; export PATH="$PYENV_ROOT/bin:$PATH"
   ./Tools/environment_install/install-prereqs-mac.sh -y
   ```
2. **STM32ツールチェーンのインストールでsudoパスワードを要求される**
   SITLには不要（実機FC用ファームを手元でビルドする時だけ必要。本計画のFWは
   Custom Buildサーバー利用予定なので当面不要）。
   → 対処: `DO_AP_STM_ENV=0` を付けてスキップ（スクリプト公式の環境変数。
   対話実行時のデフォルトもNなので挙動は公式どおり）。
   ```bash
   DO_AP_STM_ENV=0 ./Tools/environment_install/install-prereqs-mac.sh -y
   ```
3. **`mavproxy.py` が見つからない場合**は `pyenv rehash` を実行する。

## 2. ビルド

```bash
cd ~/ardupilot
./waf configure --board sitl
./waf copter        # M5で約1分45秒。build/sitl/bin/arducopter ができる
```

## 3. 起動と離陸テスト（手動・公式チュートリアル）

公式: https://ardupilot.org/dev/docs/copter-sitl-mavproxy-tutorial.html

```bash
cd ~/ardupilot/ArduCopter
sim_vehicle.py --console --map -w   # 初回のみ -w（仮想EEPROMを初期化）
```

MAVProxyのプロンプトで:

```
mode guided
arm throttle      # EKF準備完了前はPreArmで弾かれる。起動後30秒ほど待って再実行
takeoff 5         # ⚠️ armから15秒以内に打つこと（過ぎると自動disarm）
mode land
```

## 4. 起動と離陸テスト（自動・スモークテスト）

上記の手順をそのまま自動化したのが [smoke_test.py](smoke_test.py)。環境が壊れていないかの確認に使う。

```bash
python3 sitl/smoke_test.py      # リポジトリルートから
```

成功すると `SMOKE TEST PASSED` / exit 0。
初回実行結果（2026-07-08）: GUIDED→ARM→4.7m到達→LAND→disarm まで通過 ✅

## TODO

- [ ] Gazebo連携（3Dビジュアル検証。Luaの軌道確認を目視したくなった段階で追加）
- [ ] Lua 3関数の骨格（burst_takeoff / room_loop / swoop_land）をSITLで動かす — 次セッション
