(* demo.sml - CIE colour science on a few swatches: convert named sRGB colours
   to XYZ / Lab, report CIE76 / CIE94 / CIEDE2000 differences, adapt a white
   point with Bradford, and estimate a correlated colour temperature. All reals
   are printed via fmtReal, so output is identical on both compilers. *)

structure C = Colorsci
val f2 = C.fmtReal 2
val f4 = C.fmtReal 4

fun showLab name (rgb : Color.rgb) =
  let
    val xyz = C.srgbToXyz rgb
    val lab = C.xyzToLab xyz
  in
    print (name ^ ":  XYZ = (" ^ f4 (#x xyz) ^ ", " ^ f4 (#y xyz) ^ ", " ^ f4 (#z xyz)
           ^ ")   Lab = (" ^ f2 (#l lab) ^ ", " ^ f2 (#a lab) ^ ", " ^ f2 (#b lab) ^ ")\n")
  end

val white  = { r = 1.0, g = 1.0, b = 1.0 }
val steel  = { r = 0.2, g = 0.4, b = 0.6 }    (* #336699 *)
val olive  = { r = 0.5, g = 0.5, b = 0.0 }    (* #808000 *)
val salmon = { r = 0.98, g = 0.5, b = 0.45 }

val () = print "Named sRGB swatches in CIE XYZ / L*a*b* (D65):\n\n"
val () = showLab "white " white
val () = showLab "steel " steel
val () = showLab "olive " olive
val () = showLab "salmon" salmon

val labSteel  = C.xyzToLab (C.srgbToXyz steel)
val labSalmon = C.xyzToLab (C.srgbToXyz salmon)
val () = print "\nDifference between steel (#336699) and salmon:\n"
val () = print ("  CIE76     = " ^ f4 (Color.deltaE76 (labSteel, labSalmon)) ^ "\n")
val () = print ("  CIE94     = " ^ f4 (C.deltaE94 (labSteel, labSalmon)) ^ "\n")
val () = print ("  CIEDE2000 = " ^ f4 (Color.deltaE2000 (labSteel, labSalmon)) ^ "\n")

val () = print "\nBradford-adapt the D65 white to D50 (XYZ):\n"
val d50w = C.d65ToD50 (C.srgbToXyz white)
val () = print ("  " ^ "(" ^ f4 (#x d50w) ^ ", " ^ f4 (#y d50w) ^ ", " ^ f4 (#z d50w) ^ ")\n")

val () = print "\nCorrelated colour temperature (McCamy):\n"
val d65xy = C.xyzToXyy C.d65
val () = print ("  CCT of the D65 white point = " ^ f2 (C.cctMcCamy (#x d65xy, #y d65xy)) ^ " K\n")
val warm = C.planckianLocus 3200.0
val () = print ("  Planckian locus at 3200 K  = xy (" ^ f4 (#x warm) ^ ", " ^ f4 (#y warm)
                ^ "), CCT back = " ^ f2 (C.cctMcCamy (#x warm, #y warm)) ^ " K\n")
