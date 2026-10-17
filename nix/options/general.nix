# Core options: Ignis configuration, commands and runtime environment.
{
  lib,
  config,
  pkgs,
  exoSource,
  exoConfig,
  exoLib,
  inputs,
  ...
}: let
  inherit (lib) filter genAttrs listToAttrs mkEnableOption mkIf mkMerge mkOption optionals optionalString removePrefix types;

  cfg = config.exo;
  settings = import ./settings.nix {
    inherit lib;
    types = lib.types;
  };

  ignisSource = exoSource + "/ignis";

  hyprlandFragment = config.exo.compositor.enable && config.exo.compositor.type == "hyprland";

  ignisFiles = map (path: {
    inherit path;
    relative = builtins.unsafeDiscardStringContext (removePrefix "${ignisSource}/" "${path}");
  }) (exoLib.listFiles ignisSource);

  ignisFileLinks = listToAttrs (map (file: {
      name = "${cfg.ignis.directory}/${file.relative}";
      value.source = "${exoConfig}/share/exo/ignis/${file.relative}";
    })
    ignisFiles);

  toolNames = [
    "fish"
    "matugen"
    "awww"
    "adw-gtk3"
    "sass"
    "material-symbols"
    "jetbrains-mono"
    "nerd-fonts.jetbrains-mono"
    "bibata-cursors"
    "gnome-bluetooth"
    "hyprlock"
    "brightnessctl"
    "playerctl"
    "libnotify"
    "gpu-screen-recorder"
    "pipewire"
    "wireplumber"
  ];

  hyprlandToolNames = [
    "slurp"
    "hyprshot"
  ];

  mkTool = name: {
    enable = mkOption {
      type = types.bool;
      default = !(builtins.elem name hyprlandToolNames) || hyprlandFragment;
      description = ''
        Install this tool. Hyprland-only tools follow
        `exo.compositor.type == "hyprland"`.
      '';
    };
    package = mkOption {
      type = types.nullOr types.package;
      default = exoLib.availablePackage pkgs name;
      defaultText = "pkgs.${name}";
      description = ''
        Package providing this tool. Point it at your distribution's build when
        that differs, for example `config.programs.pipewire.package`.
      '';
    };
  };

  system = pkgs.stdenv.hostPlatform.system;

  gvcPackage = inputs.ignis.inputs.ignis-gvc.packages.${system}.ignis-gvc;

  ignisPackage = inputs.ignis.packages.${system}.ignis.overridePythonAttrs (old: {
    dependencies =
      old.dependencies
      ++ optionals cfg.services.audio [gvcPackage]
      ++ optionals cfg.services.network [pkgs.networkmanager]
      ++ optionals cfg.services.recorder [pkgs.gpu-screen-recorder]
      ++ optionals cfg.services.bluetooth [pkgs.gnome-bluetooth]
      ++ optionals cfg.services.dartSass [pkgs.dart-sass];
    preFixup =
      old.preFixup
      + optionalString cfg.services.audio ''
        makeWrapperArgs+=(--prefix GI_TYPELIB_PATH : "${gvcPackage}/lib/ignis-gvc")
      '';
  });

  toolPackages = filter (package: package != null) (
    map (tool: tool.package) (
      builtins.filter (tool: tool.enable) (map (name: cfg.tools.${name}) (toolNames ++ hyprlandToolNames))
    )
  );

  chosenPackages = filter (package: package != null) [
    cfg.terminal.package
    cfg.fileManager.package
    (
      if cfg.kitty.enable
      then exoLib.availablePackage pkgs "kitty"
      else null
    )
  ];
in {
  options.exo = {
    enable = mkEnableOption "the Exo desktop shell";

    package = mkOption {
      type = types.package;
      default = ignisPackage;
      defaultText = "ignis built with exo.services";
      description = "Ignis executable package, built with the services enabled below.";
    };

    services = {
      audio = mkOption {
        type = types.bool;
        default = true;
        description = "Build Ignis with Gvc, for the audio widgets.";
      };
      network = mkOption {
        type = types.bool;
        default = false;
        description = "Build Ignis with the NetworkManager service. Leave off when the network is managed by iwd or networkd.";
      };
      recorder = mkOption {
        type = types.bool;
        default = true;
        description = "Build Ignis with the screen recorder service.";
      };
      bluetooth = mkOption {
        type = types.bool;
        default = false;
        description = "Build Ignis with the gnome-bluetooth service. Leave off when Bluetooth is handled by bluez.";
      };
      dartSass = mkOption {
        type = types.bool;
        default = true;
        description = "Use dart-sass to compile Exo's stylesheets.";
      };
    };

    runtimePackages = mkOption {
      type = types.listOf types.package;
      default = [cfg.package] ++ chosenPackages ++ toolPackages;
      defaultText = "exo.package ++ exo.terminal.package ++ exo.fileManager.package ++ (kitty, when enabled) ++ the enabled exo.tools";
      description = "Runtime packages made available to the shell and its scripts.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages, for example a preferred launcher.";
    };

    tools = genAttrs (toolNames ++ hyprlandToolNames) mkTool;

    setSessionVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Expose the cursor variables below through the session environment.";
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = {
        XCURSOR_SIZE = "24";
        HYPRCURSOR_THEME = "Bibata-Modern-Classic";
        HYPRCURSOR_SIZE = "24";
      };
      description = "Environment variables used by the compositor integration.";
    };

    commands = {
      init = mkOption {
        type = types.str;
        default = "${cfg.package.pname or "ignis"} init";
        description = "Command that initialises the Ignis shell.";
      };
      launcher = mkOption {
        type = types.str;
        default = "${cfg.package.pname or "ignis"} toggle-window Launcher";
        description = "Command that opens the app launcher.";
      };
      settings = mkOption {
        type = types.str;
        default = "${cfg.package.pname or "ignis"} toggle-window Settings";
        description = "Command that opens the Ignis settings window.";
      };
      powerMenu = mkOption {
        type = types.str;
        default = "${cfg.package.pname or "ignis"} toggle-window PowerMenu";
        description = "Command that opens the power menu.";
      };
      quickCenter = mkOption {
        type = types.str;
        default = "${cfg.package.pname or "ignis"} toggle-window QuickCenter";
        description = "Command that opens the quick settings centre.";
      };
      lock = mkOption {
        type = types.str;
        default = "hyprlock";
        description = "Command that locks the session.";
      };
      wallpaperDaemon = mkOption {
        type = types.str;
        default = "${cfg.matugen.wallpaperCommand}-daemon";
        description = "Background command started by the compositor fragment.";
      };
    };

    ignis = {
      directory = mkOption {
        type = types.str;
        default = "ignis";
        description = "Directory below the XDG config home that holds Exo's Ignis configuration.";
      };
    };

    userSettings = {
      fileName = mkOption {
        type = types.str;
        default = "user_settings.json";
        description = ''
          Seed file name inside exo.ignis.directory. The shell copies it once
          into exo.userSettings.stateDirectory and writes its changes there,
          because the configuration directory can be a read-only store link.
        '';
      };
      stateDirectory = mkOption {
        type = types.str;
        default = "exo";
        description = "Directory below XDG_STATE_HOME holding Ignis' writable state.";
      };
      reset = mkOption {
        type = types.bool;
        default = false;
        description = "Re-copy the seed over the existing settings on the next start.";
      };
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional wallpaper linked at exo.wallpaperTarget.";
    };

    wallpaperTarget = mkOption {
      type = types.str;
      default = "Pictures/Wallpapers/default.png";
      description = "Path below the home directory for exo.wallpaper.";
    };

    terminal = {
      name = mkOption {
        type = types.str;
        default = "ghostty";
        description = "Command used to spawn the terminal from Exo's bindings.";
      };
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Optional terminal package to install for this user.";
      };
    };

    fileManager = {
      name = mkOption {
        type = types.str;
        default = "nautilus";
        description = "Command used to spawn the file manager from Exo's bindings.";
      };
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Optional file manager package to install for this user.";
      };
    };

    settings = settings.options;
  };

  config = mkIf cfg.enable {
    packages = cfg.runtimePackages ++ cfg.extraPackages;

    environment.sessionVariables = mkMerge [
      (mkIf cfg.setSessionVariables cfg.sessionVariables)
      (mkIf cfg.userSettings.reset {
        EXO_RESET_USER_SETTINGS = "1";
      })
    ];

    files."${cfg.wallpaperTarget}" = mkIf (cfg.wallpaper != null) {
      source = cfg.wallpaper;
    };

    xdg.config.files = lib.mkMerge [
      ignisFileLinks
      {
        # A read-only seed; Ignis copies it into XDG_STATE_HOME on first start
        # and owns the writable copy afterwards.
        "${cfg.ignis.directory}/${cfg.userSettings.fileName}".text = builtins.toJSON (
          settings.toJSON cfg.settings
        );
      }
    ];
  };
}
