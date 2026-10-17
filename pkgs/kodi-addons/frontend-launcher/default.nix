{
  buildKodiAddon,
  lib,
}:

buildKodiAddon {
  pname = "tvbox-frontend-launcher";
  namespace = "script.tvbox.frontend-launcher";
  version = "1.0.0";
  src = ./addon;

  meta = {
    description = "Launch an external nixos-tvbox frontend from Kodi";
    license = lib.licenses.mit;
  };
}
