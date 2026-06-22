(* Tests for sml-colorsci.

   Reference vectors cross-checked against published values:
     * sRGB white (1,1,1) -> XYZ = D65 (0.9505,1.0,1.0888) -> Lab (100,0,0);
     * 50% gray -> L* = 53.389; #336699 -> XYZ/Lab (matches colormine et al.);
     * CIEDE2000 (from sml-color) on rows from Sharma's published test set
       (e.g. 2.0425, 1.0000, 2.3669);
     * CIE94 on a worked pair (~1.3950);
     * Bradford D65->D50 maps the D65 white to the D50 white;
     * McCamy CCT of the D65 chromaticity ~ 6504K and a Planckian round-trip.
   Reals are compared with an epsilon; output is byte-identical across MLton and
   Poly/ML. *)

structure Tests =
struct
  open Harness
  structure C = Colorsci

  fun close eps (a, b) = Real.abs (a - b) <= eps
  fun checkClose name eps (expected, actual) =
    check name (close eps (expected, actual))
  fun closeXyz eps (a, b) = C.approxXyz eps (a, b)
  fun closeLab eps ({l=l1,a=a1,b=b1} : C.lab, {l=l2,a=a2,b=b2} : C.lab) =
    close eps (l1,l2) andalso close eps (a1,a2) andalso close eps (b1,b2)

  fun runAll () =
    let
      val white = C.srgbToXyz { r = 1.0, g = 1.0, b = 1.0 }

      val () = section "sRGB <-> XYZ <-> Lab anchors"
      val () = check "sRGB white -> XYZ = D65" (closeXyz 1.0E~4 (white, C.d65))
      val () = check "XYZ white -> Lab = (100,0,0)"
                 (closeLab 1.0E~4 (C.xyzToLab white, {l=100.0,a=0.0,b=0.0}))
      val gray = C.srgbToXyz { r = 0.5, g = 0.5, b = 0.5 }
      val grayLab = C.xyzToLab gray
      val () = checkClose "50% gray L* = 53.389" 1.0E~3 (53.389, #l grayLab)
      val () = check "50% gray is achromatic"
                 (close 1.0E~4 (0.0, #a grayLab) andalso close 1.0E~4 (0.0, #b grayLab))

      val () = section "#336699 known XYZ / Lab"
      val c336699 = C.srgbToXyz { r = 0.2, g = 0.4, b = 0.6 }
      val () = check "#336699 XYZ"
                 (closeXyz 1.0E~4 (c336699, {x=0.1186,y=0.1251,z=0.3192}))
      val () = check "#336699 Lab"
                 (closeLab 1.0E~3 (C.xyzToLab c336699, {l=42.0081,a= ~0.1517,b= ~32.8460}))
      val () = check "colorsci XYZ->Lab matches sml-color toLab (composition)"
                 (closeLab 1.0E~6 (C.xyzToLab c336699, Color.toLab {r=0.2,g=0.4,b=0.6}))

      val () = section "round trips"
      val () = check "linearRgb -> XYZ -> linearRgb"
                 (let val l = {r=0.3,g=0.55,b=0.8}
                      val r = C.xyzToLinearRgb (C.linearRgbToXyz l)
                  in close 1.0E~6 (#r l,#r r) andalso close 1.0E~6 (#g l,#g r)
                     andalso close 1.0E~6 (#b l,#b r) end)
      val () = check "XYZ -> xyY -> XYZ" (closeXyz 1.0E~9 (C.xyyToXyz (C.xyzToXyy c336699), c336699))
      val () = check "XYZ -> Lab -> XYZ" (closeXyz 1.0E~9 (C.labToXyz (C.xyzToLab c336699), c336699))
      val () = check "XYZ -> Luv -> XYZ" (closeXyz 1.0E~8 (C.luvToXyz (C.xyzToLuv c336699), c336699))
      val () = check "sRGB -> XYZ -> sRGB"
                 (let val s = C.xyzToSrgb c336699
                  in close 1.0E~6 (0.2,#r s) andalso close 1.0E~6 (0.4,#g s)
                     andalso close 1.0E~6 (0.6,#b s) end)

      val () = section "CIELUV white"
      val () = check "Luv white = (100,0,0)"
                 (let val {l,u,v} = C.xyzToLuv white
                  in close 1.0E~4 (100.0,l) andalso close 1.0E~4 (0.0,u)
                     andalso close 1.0E~4 (0.0,v) end)

      val () = section "colour difference"
      val la = {l=50.0,a=2.6772,b= ~79.7751}
      val lb = {l=50.0,a=0.0,b= ~82.7485}
      val () = checkClose "CIE94 worked pair = 1.3950" 1.0E~3 (1.3950, C.deltaE94 (la,lb))
      val () = checkClose "CIE94 identical = 0" 1.0E~9 (0.0, C.deltaE94 (la,la))
      (* CIEDE2000 from sml-color, against Sharma's published dataset *)
      val () = checkClose "dE2000 Sharma row = 2.0425" 1.0E~3 (2.0425, Color.deltaE2000 (la,lb))
      val () = checkClose "dE2000 Sharma row = 1.0000" 1.0E~3
                 (1.0000, Color.deltaE2000 ({l=50.0,a= ~1.3802,b= ~84.2814}, lb))
      val () = checkClose "dE2000 Sharma row = 2.3669" 1.0E~3
                 (2.3669, Color.deltaE2000 ({l=50.0,a=0.0,b=0.0}, {l=50.0,a= ~1.0,b=2.0}))

      val () = section "Bradford chromatic adaptation"
      val () = check "D65->D50 of D65 white = D50 white"
                 (closeXyz 1.0E~4 (C.d65ToD50 white, C.d50))
      val () = check "D50->D65 round-trips the D65 white"
                 (closeXyz 1.0E~6 (C.d50ToD65 (C.d65ToD50 white), white))
      val () = check "adapt from=to is identity"
                 (closeXyz 1.0E~5 (C.adaptXyz {from=C.d65,to=C.d65} c336699, c336699))

      val () = section "correlated colour temperature"
      val d65xy = C.xyzToXyy C.d65
      val () = checkClose "CCT(D65) ~ 6504K" 5.0 (6503.5, C.cctMcCamy (#x d65xy, #y d65xy))
      val pl = C.planckianLocus 6500.0
      val () = checkClose "Planckian 6500K -> CCT round trip" 5.0
                 (6500.0, C.cctMcCamy (#x pl, #y pl))

      val () = section "gamut + blend"
      val () = checkBool "white in sRGB gamut" (true, C.inSrgbGamut white)
      val () = checkBool "mid gray in sRGB gamut" (true, C.inSrgbGamut gray)
      val () = checkBool "imaginary colour out of gamut"
                 (false, C.inSrgbGamut {x=0.5,y=0.9,z=0.1})
      val () = check "labMix midpoint"
                 (closeLab 1.0E~9
                    (C.labMix ({l=0.0,a=0.0,b=0.0},{l=100.0,a=40.0,b= ~20.0},0.5),
                     {l=50.0,a=20.0,b= ~10.0}))
      val () = check "labMix clamps t > 1"
                 (closeLab 1.0E~9
                    (C.labMix ({l=0.0,a=0.0,b=0.0},{l=100.0,a=40.0,b= ~20.0},2.0),
                     {l=100.0,a=40.0,b= ~20.0}))
    in
      Harness.run ()
    end

  val run = runAll
end
