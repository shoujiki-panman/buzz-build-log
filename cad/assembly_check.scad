// assembly_check.scad — 機体全体の幾何チェック（組み上がるかの証拠）
// 実測値と確定部品で全体を組み、プロペラ干渉と寸法の整合を目で確認する。
// 「仮定」印の数字はバズの実測（Issue #1, #2）で差し替える。

$fn = 48;

// ==== 実測・確定値 ==========================================
prop_diag = 210;                  // ダミープロペラ対角スパン（実測）
motor_xy  = prop_diag / 2 / sqrt(2);  // モーター位置 = ±74.2mm
prop_d    = 76.2;                 // 3インチプロペラ直径（確定構成）
plate_w = 60; plate_l = 90; plate_t = 3;   // トッププレート（設計済み）

// ==== 部品の想定寸法 ========================================
arm_w = 10; arm_t = 10;           // カーボン角パイプ10×10（両対応案の片方）
motor_d = 25; motor_h = 15;       // F2004クラスの外形
prop_z  = plate_t + motor_h + 4;  // プロペラ回転面の高さ

// ==== バズの外形（★仮定 — 実測で差し替え）==================
buzz_l = 195;   // 全高195mm（実測: 19.5cm）→ うつ伏せ飛行姿勢で前後方向
buzz_w = 90;    // ★仮定: 腕を体側に沿わせたポーズの最大幅
buzz_t = 55;    // ★仮定: 胸の厚み
lid_h  = 40;    // ★仮定: ジェットパック上蓋からバズ背面までの高さ

// ==== 電池（重心調整の可変要素）=============================
batt = [30, 60, 15]; batt_y = -20;   // プレート上・前後に動かせる

// ==== 検算をコンソールに出す ================================
echo(str("モーター位置: ±", motor_xy, "mm（対角", prop_diag, "mm）"));
echo(str("隣接プロペラの隙間: ", prop_diag/sqrt(2) - prop_d, "mm（>0で干渉なし）"));
echo(str("プロペラ円の内側の縁: 中心から", motor_xy - prop_d/2, "mm（体の幅はこの内側×2に収める）"));

// ==== モデル ================================================
// トッププレート
color("gray") linear_extrude(plate_t)
  offset(r=6) square([plate_w-12, plate_l-12], center=true);

// アーム4本（プレート角→モーター位置、45°）
for (sx=[-1,1], sy=[-1,1])
  color([0.2,0.2,0.2])
    hull() {
      translate([sx*22, sy*37, plate_t/2]) cube([arm_w, arm_w, arm_t], center=true);
      translate([sx*motor_xy, sy*motor_xy, plate_t/2]) cube([arm_w, arm_w, arm_t], center=true);
    }

// モーター4基
for (sx=[-1,1], sy=[-1,1])
  color("orange") translate([sx*motor_xy, sy*motor_xy, plate_t])
    cylinder(d=motor_d, h=motor_h);

// プロペラ回転面（半透明の円盤）
for (sx=[-1,1], sy=[-1,1])
  color([1,0,0,0.35]) translate([sx*motor_xy, sy*motor_xy, prop_z])
    cylinder(d=prop_d, h=1.5);

// 電池
color("green") translate([0, batt_y, plate_t + arm_t])
  cube(batt, center=true);

// バズ（うつ伏せ・上蓋の下にぶら下がる想定の外形箱）
color([0.3,0.5,1,0.55]) translate([0, 0, -lid_h - buzz_t/2])
  cube([buzz_w, buzz_l, buzz_t], center=true);
// 頭の目印（+Y側）
color([0.3,0.5,1,0.7]) translate([0, buzz_l/2 - 20, -lid_h - buzz_t/2])
  sphere(d=45);
