{
  lib,

  libcec,
}:

libcec.overrideAttrs (old: {
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ (lib.cmakeBool "HAVE_AOCEC_API" true) ];
})
