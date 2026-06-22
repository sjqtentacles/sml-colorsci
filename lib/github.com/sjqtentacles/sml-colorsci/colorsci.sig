(* colorsci.sig

   CIE colour-science extensions built ON TOP of sml-color. sml-color already
   provides sRGB <-> linear, sRGB <-> CIE L*a*b*, Lab <-> LCh, and the CIE76 /
   CIEDE2000 colour differences; this library adds the pieces it lacks and
   composes with it rather than duplicating its conversions:

     * explicit CIE XYZ as a first-class type, with sRGB / linear-RGB <-> XYZ,
       XYZ <-> xyY, XYZ <-> CIELAB (white-point parameterised), XYZ <-> CIELUV;
     * the CIE94 colour difference (CIE76 and CIEDE2000 live in sml-color and
       are re-used directly);
     * Bradford chromatic adaptation between white points (e.g. D65 <-> D50);
     * correlated colour temperature: a Planckian-locus approximation
       (Kim et al., T -> xy) and McCamy's approximation (xy -> CCT);
     * an sRGB gamut check and a Lab-space linear blend.

   All channel reals follow sml-color: RGB in [0,1], Lab L* in [0,100]. XYZ is on
   the Y in [0,1] scale. The D65 reference white is (0.95047, 1.0, 1.08883).
   Everything is pure and deterministic; reals are compared with an epsilon and
   printed via `fmtReal`. *)

signature COLORSCI =
sig
  type rgb = { r : real, g : real, b : real }     (* = Color.rgb *)
  type lab = { l : real, a : real, b : real }       (* = Color.lab *)
  type xyz = { x : real, y : real, z : real }
  type xyy = { x : real, y : real, capY : real }    (* chromaticity x,y + luminance Y *)
  type luv = { l : real, u : real, v : real }

  (* ---- reference white points (XYZ, Y = 1) ---- *)
  val d65 : xyz
  val d50 : xyz

  (* ---- XYZ conversions (sRGB / D65 primaries) ---- *)
  val linearRgbToXyz : rgb -> xyz          (* input is LINEAR rgb *)
  val xyzToLinearRgb : xyz -> rgb
  val srgbToXyz : rgb -> xyz                (* gamma-encoded sRGB -> XYZ *)
  val xyzToSrgb : xyz -> rgb                (* XYZ -> gamma-encoded sRGB (clamped) *)

  val xyzToXyy : xyz -> xyy
  val xyyToXyz : xyy -> xyz

  (* CIELAB relative to a white point; the unprimed versions use D65. *)
  val xyzToLabWith : xyz -> xyz -> lab      (* white -> xyz -> lab *)
  val labToXyzWith : xyz -> lab -> xyz
  val xyzToLab : xyz -> lab
  val labToXyz : lab -> xyz

  (* CIELUV relative to a white point; the unprimed versions use D65. *)
  val xyzToLuvWith : xyz -> xyz -> luv
  val luvToXyzWith : xyz -> luv -> xyz
  val xyzToLuv : xyz -> luv
  val luvToXyz : luv -> xyz

  (* ---- colour difference ---- *)
  val deltaE94 : lab * lab -> real          (* CIE94, graphics weights *)

  (* ---- chromatic adaptation (Bradford) ---- *)
  val adaptXyz : { from : xyz, to : xyz } -> xyz -> xyz
  val d65ToD50 : xyz -> xyz
  val d50ToD65 : xyz -> xyz

  (* ---- correlated colour temperature ---- *)
  val planckianLocus : real -> xyy          (* Kelvin -> xyY chromaticity (Y=1) *)
  val cctMcCamy      : real * real -> real   (* (x, y) -> CCT in Kelvin *)

  (* ---- gamut + blending ---- *)
  val inSrgbGamut : xyz -> bool             (* does XYZ map inside the sRGB cube? *)
  val labMix : lab * lab * real -> lab       (* linear blend in Lab; t clamped *)

  (* ---- helpers ---- *)
  val approxXyz : real -> xyz * xyz -> bool
  val fmtReal : int -> real -> string
end
