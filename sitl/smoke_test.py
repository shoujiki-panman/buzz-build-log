#!/usr/bin/env python3
"""SITL smoke test — ARM→離陸→着陸が通れば環境構築OK。

公式Copter SITLチュートリアルの手順をそのまま自動化したもの:
  sim_vehicle.py -w を起動 → mode guided → arm throttle → takeoff 5 → mode land
https://ardupilot.org/dev/docs/copter-sitl-mavproxy-tutorial.html

使い方:
  python3 sitl/smoke_test.py [--ardupilot ~/ardupilot]
成功すると "SMOKE TEST PASSED" を表示して exit 0。
"""
import argparse
import os
import sys
import time

import pexpect

TAKEOFF_ALT_M = 5          # takeoff目標高度
PASS_ALT_MM = 4500         # 相対高度がこれ(mm)を超えたら離陸成功
BOOT_TIMEOUT_S = 300       # SITL起動〜EKF準備完了まで
ARM_RETRY = 30             # PreArm待ちのarm再試行回数


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ardupilot", default=os.path.expanduser("~/ardupilot"))
    args = ap.parse_args()

    copter_dir = os.path.join(args.ardupilot, "ArduCopter")
    env = os.environ.copy()
    env["PATH"] = os.pathsep.join([
        os.path.expanduser("~/.pyenv/shims"),
        os.path.join(args.ardupilot, "Tools", "autotest"),
        env.get("PATH", ""),
    ])

    print(f"[smoke] starting sim_vehicle.py -w in {copter_dir}")
    child = pexpect.spawn(
        "sim_vehicle.py", ["-w"],
        cwd=copter_dir, env=env, encoding="utf-8", timeout=BOOT_TIMEOUT_S,
    )
    child.logfile_read = sys.stdout

    try:
        # EKFがGPS(模擬)を使い始めるまで待つ = 位置推定準備完了のサイン
        child.expect(r"using GPS", timeout=BOOT_TIMEOUT_S)
        time.sleep(10)  # EKF安定待ち

        child.sendline("mode guided")
        child.expect(r"GUIDED", timeout=30)

        # PreArmチェックが通るまでarmを再試行（起動直後は弾かれるのが正常）
        armed = False
        for i in range(ARM_RETRY):
            child.sendline("arm throttle")
            idx = child.expect(
                [r"Arming motors|ARMED", r"PreArm|Disarm|COMMAND_ACK.*4", pexpect.TIMEOUT],
                timeout=10,
            )
            if idx == 0:
                armed = True
                break
            print(f"[smoke] arm retry {i + 1}/{ARM_RETRY}")
            time.sleep(5)
        if not armed:
            raise RuntimeError("could not arm within retry budget")

        # 離陸はarm後15秒以内が必須（過ぎると自動disarm）
        child.sendline(f"takeoff {TAKEOFF_ALT_M}")
        child.sendline("watch GLOBAL_POSITION_INT")
        deadline = time.time() + 120
        reached = False
        while time.time() < deadline:
            child.expect(r"relative_alt\"?\s*:\s*(-?\d+)", timeout=30)
            alt_mm = int(child.match.group(1))
            if alt_mm >= PASS_ALT_MM:
                reached = True
                print(f"\n[smoke] reached {alt_mm / 1000:.1f} m")
                break
        child.sendline("watch none")
        if not reached:
            raise RuntimeError("takeoff altitude not reached in 120s")

        child.sendline("mode land")
        child.expect(r"Disarming motors|DISARMED", timeout=180)
        print("\n[smoke] landed and disarmed")
        print("SMOKE TEST PASSED")
        return 0
    finally:
        child.sendline("")
        child.close(force=True)


if __name__ == "__main__":
    sys.exit(main())
