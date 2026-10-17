_final: lib:

{
  # Read source metadata from the initial assignment block, without evaluating
  # shell code. Only double-quoted values and simple variable references are
  # supported; build functions and the rest of the recipe are ignored.
  readPackageMk =
    path:
    let
      fail = message: throw "${toString path}: ${message}";
      lines = lib.splitString "\n" (builtins.readFile path);
      headerEnd = lib.lists.findFirstIndex (
        line:
        builtins.match "[[:space:]]*(#.*)?" line == null
        && builtins.match "[A-Z_][A-Z0-9_]*=.*" line == null
      ) (builtins.length lines) lines;
      header = lib.take headerEnd lines;
      read =
        name: fallback:
        let
          assignments = builtins.filter (lib.hasPrefix "${name}=") header;
          value = builtins.match "${name}=\"([^\"\\\\]*)\"[[:space:]]*(#.*)?" (builtins.head assignments);
        in
        if assignments == [ ] then
          if fallback == null then fail "missing ${name}" else fallback
        else if builtins.length assignments != 1 || value == null then
          fail "expected one literal double-quoted assignment for ${name}"
        else
          builtins.head value;
      expand =
        variables: name: raw:
        let
          value = lib.concatMapStrings (
            part:
            if builtins.isString part then
              part
            else
              let
                variable = lib.findFirst (v: v != null) "" part;
              in
              variables.${variable} or (fail "unknown variable ${variable} in ${name}")
          ) (builtins.split "[$][{]([A-Za-z_][A-Za-z0-9_]*)[}]|[$]([A-Za-z_][A-Za-z0-9_]*)" raw);
        in
        if
          lib.any (character: lib.hasInfix character value) [
            "$"
            "`"
            "\\"
          ]
        then
          fail "unsupported shell syntax in ${name}"
        else
          value;
      fields = rec {
        PKG_NAME = expand { } "PKG_NAME" (read "PKG_NAME" null);
        PKG_VERSION = expand { inherit PKG_NAME; } "PKG_VERSION" (read "PKG_VERSION" null);
        PKG_SHA256 = expand { } "PKG_SHA256" (read "PKG_SHA256" "");
        PKG_SOURCE_NAME = expand {
          inherit PKG_NAME PKG_VERSION;
        } "PKG_SOURCE_NAME" (read "PKG_SOURCE_NAME" "");
        PKG_URL = expand (
          {
            inherit PKG_NAME PKG_VERSION;
          }
          // lib.optionalAttrs (PKG_SOURCE_NAME != "") { inherit PKG_SOURCE_NAME; }
        ) "PKG_URL" (read "PKG_URL" null);
      };
    in
    if
      lib.any (name: fields.${name} == "") [
        "PKG_NAME"
        "PKG_VERSION"
        "PKG_URL"
      ]
    then
      fail "source metadata must include a nonempty PKG_NAME, PKG_VERSION and PKG_URL"
    else
      fields;
}
