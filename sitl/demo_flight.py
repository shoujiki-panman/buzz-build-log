#!/usr/bin/env python3
"""バズの飛び方3つをSITLで通しで流すテスト。

人がデモでやる操作（motion/README.md）とまったく同じことを自動でやる:
  GUIDED → arm → SCR_USER1=1(急上昇) → 2(部屋一周) → 3(降りて着地)
3つとも完走すると "DEMO FLIGHT PASSED" を表示して exit 0。

使い方:
  python3 sitl/demo_flight.py [--ardupilot ~/ardupilot]
前提: motion/buzz_motion.lua が ~/ardupilot/ArduCopter/scripts/ に置いて（リンクして）あること。
"""
import argparse
import os
import sys
import time

import pexpect

BOOT_TIMEOUT_S = 300
ARM_RETRY = 30


def wait_boot(child):
    """EKFが位置をつかむまで待つ（起動完了のサイン）"""
    child.expect(r"using GPS", timeout=BOOT_TIMEOUT_S)
    time.sleep(10)


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

    # SCR_ENABLE=1（Lua有効化）を起動時から渡す。再起動は不安定なので使わない
    parm = os.path.join(os.path.dirname(os.path.abspath(__file__)), "buzz_sitl.parm")

    print(f"[demo] starting sim_vehicle.py in {copter_dir}")
    child = pexpect.spawn(
        "sim_vehicle.py", [f"--add-param-file={parm}"],
        cwd=copter_dir, env=env, encoding="utf-8", timeout=BOOT_TIMEOUT_S,
    )
    child.logfile_read = sys.stdout

    try:
        # スクリプトが読み込まれた合図 → 位置推定の準備完了、の順で待つ
        child.expect(r"motion script ready", timeout=BOOT_TIMEOUT_S)
        wait_boot(child)

        child.sendline("mode guided")
        child.expect(r"GUIDED", timeout=30)

        armed = False
        for i in range(ARM_RETRY):
            child.sendline("arm throttle")
            idx = child.expect(
                [r"Arming motors|ARMED", r"PreArm|Disarm", pexpect.TIMEOUT],
                timeout=10,
            )
            if idx == 0:
                armed = True
                break
            print(f"[demo] arm retry {i + 1}/{ARM_RETRY}")
            time.sleep(5)
        if not armed:
            raise RuntimeError("could not arm")

        # --- 1. 急上昇 ---
        child.sendline("param set SCR_USER1 1")
        child.expect(r"burst_takeoff done", timeout=90)
        print("\n[demo] 1/3 burst_takeoff OK")

        # --- 2. 部屋一周 ---
        child.sendline("param set SCR_USER1 2")
        child.expect(r"room_loop done", timeout=240)
        print("\n[demo] 2/3 room_loop OK")

        # --- 3. 降りて着地 ---
        child.sendline("param set SCR_USER1 3")
        child.expect(r"swoop_land: LAND", timeout=120)
        child.expect(r"swoop_land done|Disarming motors", timeout=180)
        print("\n[demo] 3/3 swoop_land OK")

        print("DEMO FLIGHT PASSED")
        return 0
    finally:
        child.sendline("")
        child.close(force=True)


if __name__ == "__main__":
    sys.exit(main())
