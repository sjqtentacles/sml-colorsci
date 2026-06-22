(* colorsci.sml

   Implementation of COLORSCI. Builds on the vendored `Color` structure: sRGB
   gamma <-> linear transfer functions are reused from sml-color, and CIE76 /
   CIEDE2000 differences remain in sml-color. Everything here is the CIE
   colour-science layer that sml-color does not provide. *)

structure Colorsci :> COLORSCI =
struct
  type rgb = { r : real, g : real, b : real }
  type lab = { l : real, a : real, b : real }
  type xyz = { x : real, y : real, z : real }
  type xyy = { x : real, y : real, capY : real }
  type luv = { l : real, u : real, v : real }

  fun fmtReal n r =
    let val s = Real.fmt (StringCvt.FIX (SOME n)) r
    in if String.isPrefix "~" s then "-" ^ String.extract (s, 1, NONE) else s end

  (* reference whites on the Y = 1 scale *)
  val d65 : xyz = { x = 0.95047, y = 1.0, z = 1.08883 }
  val d50 : xyz = { x = 0.96422, y = 1.0, z = 0.82521 }

  (* ---- XYZ <-> RGB (sRGB primaries, D65) ---- *)
  fun linearRgbToXyz ({ r, g, b } : rgb) : xyz =
    { x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
      y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
      z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b }

  fun xyzToLinearRgb ({ x, y, z } : xyz) : rgb =
    { r =  3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
      g = ~0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
      b =  0.0556434 * x - 0.2040259 * y + 1.0572252 * z }

  (* reuse sml-color's sRGB transfer functions *)
  fun srgbToXyz c = linearRgbToXyz (Color.rgbToLinear c)
  fun xyzToSrgb xyz = Color.clampRgb (Color.rgbToSrgb (xyzToLinearRgb xyz))

  (* ---- XYZ <-> xyY ---- *)
  fun xyzToXyy ({ x, y, z } : xyz) : xyy =
    let val s = x + y + z
    in if Real.== (s, 0.0) then { x = 0.0, y = 0.0, capY = 0.0 }
       else { x = x / s, y = y / s, capY = y } end

  fun xyyToXyz ({ x, y, capY } : xyy) : xyz =
    if Real.== (y, 0.0) then { x = 0.0, y = 0.0, z = 0.0 }
    else { x = x * capY / y, y = capY, z = (1.0 - x - y) * capY / y }

  (* ---- CIE Lab nonlinearity (delta = 6/29), shared by Lab/Luv ---- *)
  val labDelta  = 6.0 / 29.0
  val labDelta3 = labDelta * labDelta * labDelta
  fun labF t =
    if t > labDelta3 then Math.pow (t, 1.0 / 3.0)
    else t / (3.0 * labDelta * labDelta) + 4.0 / 29.0
  fun labFinv t =
    if t > labDelta then t * t * t
    else 3.0 * labDelta * labDelta * (t - 4.0 / 29.0)

  fun xyzToLabWith ({ x = xn, y = yn, z = zn } : xyz) ({ x, y, z } : xyz) : lab =
    let val fx = labF (x / xn) and fy = labF (y / yn) and fz = labF (z / zn)
    in { l = 116.0 * fy - 16.0, a = 500.0 * (fx - fy), b = 200.0 * (fy - fz) } end

  fun labToXyzWith ({ x = xn, y = yn, z = zn } : xyz) ({ l, a, b } : lab) : xyz =
    let val fy = (l + 16.0) / 116.0
        val fx = fy + a / 500.0
        val fz = fy - b / 200.0
    in { x = xn * labFinv fx, y = yn * labFinv fy, z = zn * labFinv fz } end

  fun xyzToLab xyz = xyzToLabWith d65 xyz
  fun labToXyz lab = labToXyzWith d65 lab

  (* ---- CIE Luv ---- *)
  fun uvPrime ({ x, y, z } : xyz) =
    let val d = x + 15.0 * y + 3.0 * z
    in if Real.== (d, 0.0) then (0.0, 0.0) else (4.0 * x / d, 9.0 * y / d) end

  val kappa = (29.0 / 3.0) * (29.0 / 3.0) * (29.0 / 3.0)  (* (29/3)^3 = 903.296... *)

  fun xyzToLuvWith (white : xyz) (c as { x, y, z } : xyz) : luv =
    let
      val (up, vp) = uvPrime c
      val (unp, vnp) = uvPrime white
      val yr = y / (#y white)
      val l = if yr > labDelta3 then 116.0 * Math.pow (yr, 1.0 / 3.0) - 16.0
              else kappa * yr
      val u = 13.0 * l * (up - unp)
      val v = 13.0 * l * (vp - vnp)
    in { l = l, u = u, v = v } end

  fun luvToXyzWith (white : xyz) ({ l, u, v } : luv) : xyz =
    if Real.== (l, 0.0) then { x = 0.0, y = 0.0, z = 0.0 }
    else
      let
        val (unp, vnp) = uvPrime white
        val up = u / (13.0 * l) + unp
        val vp = v / (13.0 * l) + vnp
        val y = if l > 8.0 then (#y white) * Math.pow ((l + 16.0) / 116.0, 3.0)
                else (#y white) * l / kappa
      in
        if Real.== (vp, 0.0) then { x = 0.0, y = y, z = 0.0 }
        else { x = y * 9.0 * up / (4.0 * vp),
               y = y,
               z = y * (12.0 - 3.0 * up - 20.0 * vp) / (4.0 * vp) }
      end

  fun xyzToLuv xyz = xyzToLuvWith d65 xyz
  fun luvToXyz luv = luvToXyzWith d65 luv

  (* ---- CIE94 colour difference (graphics weights, reference = colour 1) ---- *)
  fun deltaE94 ({ l = l1, a = a1, b = b1 } : lab, { l = l2, a = a2, b = b2 } : lab) =
    let
      val dl = l1 - l2
      val c1 = Math.sqrt (a1 * a1 + b1 * b1)
      val c2 = Math.sqrt (a2 * a2 + b2 * b2)
      val dc = c1 - c2
      val da = a1 - a2 and db = b1 - b2
      val dh2 = da * da + db * db - dc * dc
      val dh = if dh2 > 0.0 then Math.sqrt dh2 else 0.0
      val sc = 1.0 + 0.045 * c1
      val sh = 1.0 + 0.015 * c1
      val tl = dl
      val tc = dc / sc
      val th = dh / sh
    in Math.sqrt (tl * tl + tc * tc + th * th) end

  (* ---- Bradford chromatic adaptation ---- *)
  fun bradford ({ x, y, z } : xyz) =
    ( 0.8951 * x + 0.2664 * y - 0.1614 * z,
      ~0.7502 * x + 1.7135 * y + 0.0367 * z,
      0.0389 * x - 0.0685 * y + 1.0296 * z )

  fun bradfordInv (rho, gam, bet) : xyz =
    { x =  0.9869929 * rho - 0.1470543 * gam + 0.1599627 * bet,
      y =  0.4323053 * rho + 0.5183603 * gam + 0.0492912 * bet,
      z = ~0.0085287 * rho + 0.0400428 * gam + 0.9684867 * bet }

  fun adaptXyz { from, to } xyz =
    let
      val (sr, sg, sb) = bradford from
      val (dr, dg, db) = bradford to
      val (xr, xg, xb) = bradford xyz
    in
      bradfordInv (xr * dr / sr, xg * dg / sg, xb * db / sb)
    end

  fun d65ToD50 c = adaptXyz { from = d65, to = d50 } c
  fun d50ToD65 c = adaptXyz { from = d50, to = d65 } c

  (* ---- correlated colour temperature ---- *)
  (* Kim et al. Planckian-locus approximation, valid ~1667K..25000K *)
  fun planckianLocus t : xyy =
    let
      val xc =
        if t <= 4000.0 then
          ~0.2661239e9 / (t * t * t) - 0.2343589e6 / (t * t)
          + 0.8776956e3 / t + 0.179910
        else
          ~3.0258469e9 / (t * t * t) + 2.1070379e6 / (t * t)
          + 0.2226347e3 / t + 0.240390
      val xc2 = xc * xc
      val xc3 = xc2 * xc
      val yc =
        if t <= 2222.0 then
          ~1.1063814 * xc3 - 1.34811020 * xc2 + 2.18555832 * xc - 0.20219683
        else if t <= 4000.0 then
          ~0.9549476 * xc3 - 1.37418593 * xc2 + 2.09137015 * xc - 0.16748867
        else
          3.0817580 * xc3 - 5.87338670 * xc2 + 3.75112997 * xc - 0.37001483
    in { x = xc, y = yc, capY = 1.0 } end

  (* McCamy's cubic approximation: chromaticity (x,y) -> CCT *)
  fun cctMcCamy (x, y) =
    let val n = (x - 0.3320) / (y - 0.1858)
    in ~449.0 * n * n * n + 3525.0 * n * n - 6823.3 * n + 5520.33 end

  (* ---- gamut + blend ---- *)
  fun inSrgbGamut xyz =
    let
      val { r, g, b } = xyzToLinearRgb xyz
      val eps = 1.0E~6
      fun ok v = v >= ~eps andalso v <= 1.0 + eps
    in ok r andalso ok g andalso ok b end

  fun labMix ({ l = l1, a = a1, b = b1 } : lab, { l = l2, a = a2, b = b2 } : lab, t) =
    let val tc = if t < 0.0 then 0.0 else if t > 1.0 then 1.0 else t
    in { l = l1 + (l2 - l1) * tc, a = a1 + (a2 - a1) * tc, b = b1 + (b2 - b1) * tc } end

  fun approxXyz eps ({ x = x1, y = y1, z = z1 } : xyz, { x = x2, y = y2, z = z2 } : xyz) =
    Real.abs (x1 - x2) <= eps andalso Real.abs (y1 - y2) <= eps
    andalso Real.abs (z1 - z2) <= eps
end
