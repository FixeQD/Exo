{lib}: let
  inherit
    (lib)
    attrByPath
    concatMap
    concatStringsSep
    filter
    hasInfix
    hasPrefix
    mapAttrsToList
    optionalString
    removePrefix
    splitString
    toString
    ;
in rec {
  tomlString = value: builtins.toJSON value;

  boolToToml = value:
    if value
    then "true"
    else "false";

  renderMatugenTemplate = name: value: ''
    [templates.${name}]
    input_path = ${tomlString value.inputPath}
    output_path = ${tomlString value.outputPath}
    ${optionalString (value.postHook != null) "post_hook = ${tomlString value.postHook}"}
  '';

  renderKittyKeybindings = keybindings: concatStringsSep "\n" (mapAttrsToList (key: action: "map ${key} ${action}") keybindings);

  renderPairs = separator: render: attrs: concatStringsSep separator (mapAttrsToList (name: value: render name value) attrs);

  renderHyprlandSources = sources: concatStringsSep "\n" (map (source: "source = ${source}") sources);

  # An autostart entry is either a command string or an argv list.
  renderArgs = entry:
    concatStringsSep " " (map (arg: "\"${arg}\"") (
      if builtins.isList entry
      then entry
      else [entry]
    ));

  renderHyprlandAutostart = commands: concatStringsSep "\n" (map (command: "exec-once = ${renderArgs command}") commands);

  renderHyprlandVariables = variables:
    renderPairs "\n" (name: variable: "${variable.name} = ${variable.value}") variables;

  renderHyprlandEnvironment = variables:
    renderPairs "\n" (name: value: "env = ${name},${value}") variables;

  renderHyprlandBindings = bindings: renderPairs "\n" (_: value: "bind = ${value}") bindings;

  renderNiriAutostart = commands: concatStringsSep "\n" (map (command: "spawn-at-startup ${renderArgs command}") commands);

  listFiles = dir: let
    entries = builtins.readDir (toString dir);
    entryType = entry:
      if builtins.isAttrs entry
      then entry.type or "unknown"
      else entry;
    walk = name: let
      path = "${dir}/${name}";
    in
      if entryType entries.${name} == "directory"
      then listFiles path
      else if entryType entries.${name} == "regular"
      then [path]
      else [];
  in
    filter (path: !hasInfix "/__pycache__/" "${path}") (concatMap walk (lib.attrNames entries));

  homeRelative = home: dir: let
    absolute = toString dir;
    prefix = "${home}/";
  in
    if hasPrefix prefix absolute
    then "~/${removePrefix prefix absolute}"
    else absolute;

  # `null` for packages this nixpkgs does not have.
  availablePackage = pkgs: name: let
    value = attrByPath (splitString "." name) null pkgs;
  in
    if value == null
    then null
    else value;

  availablePackages = pkgs: names: lib.filter (package: package != null) (builtins.map (availablePackage pkgs) names);
}
