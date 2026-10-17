{
  alsa-lib,
  coreelecSource,
}:

alsa-lib.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    install -m 0644 \
      ${coreelecSource}/projects/Amlogic-ce/filesystem/usr/share/alsa/cards/AML-AUGESOUND.conf \
      $out/share/alsa/cards/AML-AUGESOUND.conf
  '';
})
