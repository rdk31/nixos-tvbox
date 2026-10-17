{ libcrossguid }:

libcrossguid.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    mkdir -p "$out/lib/pkgconfig"
    cat > "$out/lib/pkgconfig/crossguid.pc" <<EOF
    prefix=$out
    includedir=$out/include
    libdir=$out/lib

    Name: crossguid
    Description: Cross-platform GUID library
    Version: 2016-02-21
    Libs: -L$out/lib -lcrossguid
    Cflags: -I$out/include
    EOF
  '';
})
