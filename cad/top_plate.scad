// PROJECT BUZZ — カーボントッププレート（パラメトリック）
// 引き継ぎ§6-1: 90×60×3mm。座標系は原寸テンプレPDF準拠（中心原点、モーターは±74mm対角＝板の外）。
// 冒頭の数字をいじって保存すれば形が変わる。実測が来たら TODO の行に値を入れる。

$fn = 64;

// ==== 板そのもの ============================================
plate_w  = 60;   // 横幅 (X) mm — ジェットパック上蓋(横65〜70)より少し小さく
plate_l  = 90;   // 縦   (Y) mm — 上蓋(縦100〜110)より少し小さく
plate_t  = 3;    // 板厚 mm（3mmカーボン想定）
corner_r = 6;    // 角の丸み

// ==== FCスタック穴（SpeedyBee F405 Mini = 20×20 M3）=========
stack_pitch  = 20;
stack_hole_d = 3.5;  // M3ボルト＋シリコングロメット径を考慮

// ==== アーム結合穴（四隅、45°対角線上に各2穴）================
// アーム断面は未確定（カーボン角パイプ10×10 or 平棒）のため、
// どちらでも使える「対角線上のM3穴2個」をベースにする。
// 角パイプの場合は別部品のブラケット（§6-2、3Dプリント）で挟む。
arm_hole_d = 3.2;          // M3通し
arm_hole_r = [26, 36];     // 中心からの距離 mm（対角線上）。ブラケット設計に合わせて調整可

// ==== 純正上蓋への固定ボルト穴 ================================
// TODO(採寸待ち): 上蓋のボス位置・ネジ穴位置を実測したら [x, y] を追記する
// 例: lid_holes = [[-20, 35], [20, 35], [-20, -35], [20, -35]];
lid_holes  = [];
lid_hole_d = 3.2;

// ==== 形状 ====================================================
module plate_2d() {
  offset(r = corner_r)
    square([plate_w - 2 * corner_r, plate_l - 2 * corner_r], center = true);
}

module holes_2d() {
  // FCスタック 20×20
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * stack_pitch / 2, sy * stack_pitch / 2])
      circle(d = stack_hole_d);

  // アーム結合（四隅の対角線上に各2穴）
  for (sx = [-1, 1], sy = [-1, 1], r = arm_hole_r)
    translate([sx * r * cos(45), sy * r * sin(45)])
      circle(d = arm_hole_d);

  // 純正上蓋への固定（採寸後に lid_holes へ追記すると穴が開く）
  for (p = lid_holes)
    translate(p)
      circle(d = lid_hole_d);
}

linear_extrude(height = plate_t)
  difference() {
    plate_2d();
    holes_2d();
  }

// 参考: モーター中心は (±74, ±74) = 対角スパン210mm（板の外側、アーム先端）
echo(str("plate ", plate_w, "x", plate_l, "x", plate_t,
         "mm / stack 20x20 / arm holes r=", arm_hole_r,
         " / lid holes: ", len(lid_holes), "個（採寸待ち）"));
