{
  lib,
  fetchFromGitHub,

  kodi,
  nlohmann_json,
}:

let
  inputstreamAdaptive =
    let
      bento4 = fetchFromGitHub {
        owner = "xbmc";
        repo = "Bento4";
        rev = "1.6.0-641-6-Piers";
        hash = "sha256-eifKqTchshA1mfOvKlpCbBZmvpqOgNi2JNWir51hOXE=";
      };
      bento4Flag = "-DBENTO4_URL=${bento4}";
    in
    kodi.packages.inputstream-adaptive.overrideAttrs (old: {
      name = "kodi-inputstream-adaptive-22.3.19-Piers";
      version = "22.3.19-Piers";
      src = fetchFromGitHub {
        owner = "xbmc";
        repo = "inputstream.adaptive";
        rev = "22.3.19-Piers";
        hash = "sha256-FSwDnrLalJX7SACL4d6Kur3zaRe5rHlnAErnKTEiES8=";
      };
      buildInputs = (old.buildInputs or [ ]) ++ [ nlohmann_json ];
      cmakeFlags =
        map (flag: if lib.hasPrefix "-DBENTO4_URL=" flag then bento4Flag else flag) (old.cmakeFlags or [ ])
        ++ [ (lib.cmakeBool "ENABLE_INTERNAL_BENTO4" true) ];
    });
in
kodi.packages.youtube.override {
  inputstream-adaptive = inputstreamAdaptive;
}
