# sml-colorsci

[![CI](https://github.com/sjqtentacles/sml-colorsci/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-colorsci/actions/workflows/ci.yml)

CIE colour-science extensions in pure Standard ML, built **on top of**
[`sml-color`](https://github.com/sjqtentacles/sml-color). It adds the pieces
`sml-color` lacks and composes with it rather than duplicating its conversions.
Pure and deterministic — reals are compared with an epsilon and printed via
`fmtReal`, so output is byte-identical under **MLton** and **Poly/ML**.

`sml-color` already provides sRGB ↔ linear, sRGB ↔ CIE L\*a\*b\*, Lab ↔ LCh, and
the CIE76 / CIEDE2000 colour differences. This library reuses those and adds:

- **Explicit CIE XYZ** as a first-class type: sRGB / linear-RGB ↔ XYZ, XYZ ↔ xyY,
  XYZ ↔ CIELAB (white-point parameterised), XYZ ↔ CIELUV.
- **CIE94** colour difference (CIE76 and CIEDE2000 stay in `sml-color`).
- **Bradford chromatic adaptation** between white points (`d65ToD50`, `d50ToD65`,
  general `adaptXyz`).
- **Correlated colour temperature**: a Planckian-locus approximation (Kim et al.,
  `T → xy`) and McCamy's approximation (`xy → CCT`).
- An **sRGB gamut check** and a **Lab-space linear blend**.

The D65 reference white is `(0.95047, 1.0, 1.08883)`; XYZ is on the `Y ∈ [0,1]`
scale, RGB channels in `[0,1]`, `L*` in `[0,100]`.

## API

```sml
structure Colorsci : sig
  type rgb = { r : real, g : real, b : real }
  type lab = { l : real, a : real, b : real }
  type xyz = { x : real, y : real, z : real }
  type xyy = { x : real, y : real, capY : real }
  type luv = { l : real, u : real, v : real }
  val d65 : xyz   val d50 : xyz
  val linearRgbToXyz : rgb -> xyz   val xyzToLinearRgb : xyz -> rgb
  val srgbToXyz : rgb -> xyz         val xyzToSrgb : xyz -> rgb
  val xyzToXyy : xyz -> xyy          val xyyToXyz : xyy -> xyz
  val xyzToLabWith : xyz -> xyz -> lab   val labToXyzWith : xyz -> lab -> xyz
  val xyzToLab : xyz -> lab          val labToXyz : lab -> xyz
  val xyzToLuvWith : xyz -> xyz -> luv   val luvToXyzWith : xyz -> luv -> xyz
  val xyzToLuv : xyz -> luv          val luvToXyz : luv -> xyz
  val deltaE94 : lab * lab -> real
  val adaptXyz : { from : xyz, to : xyz } -> xyz -> xyz
  val d65ToD50 : xyz -> xyz          val d50ToD65 : xyz -> xyz
  val planckianLocus : real -> xyy   val cctMcCamy : real * real -> real
  val inSrgbGamut : xyz -> bool      val labMix : lab * lab * real -> lab
  val approxXyz : real -> xyz * xyz -> bool
  val fmtReal : int -> real -> string
end
```

`Color` (the vendored `sml-color`) supplies `Color.toLab`, `Color.deltaE76`,
`Color.deltaE2000`, etc., which compose directly with these XYZ conversions.

## Example

```sml
val xyz = Colorsci.srgbToXyz {r=0.2, g=0.4, b=0.6}     (* #336699 *)
val lab = Colorsci.xyzToLab xyz                          (* ~ (42.01, -0.15, -32.85) *)
val dE  = Colorsci.deltaE94 (lab, Colorsci.xyzToLab (Colorsci.srgbToXyz {r=0.98,g=0.5,b=0.45}))
val d50 = Colorsci.d65ToD50 (Colorsci.srgbToXyz {r=1.0,g=1.0,b=1.0})  (* ~ D50 white *)
val cct = Colorsci.cctMcCamy (0.31271, 0.32902)          (* ~ 6504 K (D65) *)
```

Running [`examples/demo.sml`](examples/demo.sml) with `make example` prints:

```
Named sRGB swatches in CIE XYZ / L*a*b* (D65):

white :  XYZ = (0.9505, 1.0000, 1.0888)   Lab = (100.00, -0.00, 0.00)
steel :  XYZ = (0.1186, 0.1251, 0.3192)   Lab = (42.01, -0.15, -32.85)
olive :  XYZ = (0.1648, 0.1986, 0.0297)   Lab = (51.68, -12.89, 56.51)
salmon:  XYZ = (0.5013, 0.3685, 0.2061)   Lab = (67.17, 45.50, 28.55)

Difference between steel (#336699) and salmon:
  CIE76     = 80.5340
  CIE94     = 55.9927
  CIEDE2000 = 47.2319

Bradford-adapt the D65 white to D50 (XYZ):
  (0.9642, 1.0000, 0.8252)

Correlated colour temperature (McCamy):
  CCT of the D65 white point = 6503.46 K
  Planckian locus at 3200 K  = xy (0.4232, 0.3991), CCT back = 3212.40 K
```

## Build & test

Requires [MLton](http://mlton.org/) and/or [Poly/ML](https://polyml.org/).

```sh
make test        # build + run the suite under MLton
make test-poly   # run the suite under Poly/ML
make all-tests   # both
make example     # build + run the demo
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-colorsci
smlpkg sync
```

Reference `lib/github.com/sjqtentacles/sml-colorsci/colorsci.mlb` from your own
`.mlb` (MLton / MLKit), or feed `sources.mlb` to `tools/polybuild` (Poly/ML). The
vendored `sml-color` source is checked in under `lib/github.com/sjqtentacles/`
and listed first in `sources.mlb`.

## Layout

```
sml.pkg                                       smlpkg manifest (requires sml-color)
Makefile                                      MLton + Poly/ML targets
.github/workflows/ci.yml                      CI: MLton + Poly/ML (from source)
lib/github.com/sjqtentacles/
  sml-color/    color.sig color.sml            vendored (built upon)
  sml-colorsci/
    colorsci.sig   COLORSCI signature
    colorsci.sml   XYZ / xyY / Lab / Luv, CIE94, Bradford, CCT, gamut
    sources.mlb    ordered source list (dep first)
    colorsci.mlb   public basis
examples/
  demo.sml       swatch conversions + deltaE + CCT
test/
  harness.sml    shared assertion harness
  test.sml       reference vectors (28 checks)
  entry.sml / main.sml
tools/polybuild  Poly/ML build wrapper
```

## Tests

28 deterministic checks against published references: sRGB white → XYZ = D65 →
Lab `(100,0,0)`; 50% gray `L* = 53.389`; `#336699` XYZ/Lab matching standard
converters; XYZ↔xyY, XYZ↔Lab, XYZ↔Luv and sRGB↔XYZ round trips; CIE94 on a
worked pair; CIEDE2000 (from `sml-color`) on rows from Sharma's published test
set (`2.0425`, `1.0000`, `2.3669`); Bradford D65→D50 mapping the D65 white to the
D50 white; McCamy CCT of D65 `≈ 6504 K` with a Planckian round-trip; and the
gamut check / Lab blend. Run `make all-tests` to verify identical output under
both compilers.

## License

MIT. See [LICENSE](LICENSE).
