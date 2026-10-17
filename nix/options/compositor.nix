# A generated fragment that the compositor sources.
{
  lib,
  config,
  exoLib,
  ...
}: let
  inherit
    (lib)
    attrByPath
    attrNames
    concatStringsSep
    elem
    mkIf
    mkOption
    splitString
    types
    ;

  exo = config.exo;
  cfg = exo.compositor;
  renderers = import ../lib/compositor.nix {inherit lib exoLib;};

  selected = attrByPath (splitString "." cfg.type) null cfg;

  variableModule = types.submodule (
    {...}: {
      options = {
        name = mkOption {
          type = types.str;
          default = "$${name}";
          description = "Variable name as written in the fragment, for example `$terminal`.";
        };
        value = mkOption {
          type = types.str;
          default = "";
          description = "Command the variable expands to.";
        };
      };
    }
  );
in {
  options.exo.compositor = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Generate an Exo compositor fragment.";
    };

    type = mkOption {
      type = types.str;
      default = "none";
      description = ''
        Which `exo.compositor.<name>` option set to render. `"none"` generates nothing; any name works as long as the matching submodule exists.
      '';
    };

    overwrite = mkOption {
      type = types.bool;
      default = false;
      description = "Allow every activation to replace an existing compositor fragment.";
    };

    autostart = mkOption {
      type = types.listOf (types.either types.str (types.listOf types.str));
      default = [
        exo.commands.init
        exo.commands.wallpaperDaemon
      ];
      description = ''
        Commands started by the fragment on compositor start. Set to an empty list to start nothing.
      '';
    };

    custom = {
      fileName = mkOption {
        type = types.str;
        default = "exo.conf";
        description = "Path of the fragment, relative to the XDG config home.";
      };
      text = mkOption {
        type = types.lines;
        default = "";
        description = "Verbatim contents of the generated fragment.";
      };
    };

    hyprland = {
      directory = mkOption {
        type = types.str;
        default = "hypr";
        description = "Directory below the XDG config home for the generated fragment.";
      };

      fileName = mkOption {
        type = types.str;
        default = "${cfg.hyprland.directory}/exo.conf";
        defaultText = "exo.compositor.hyprland.directory + \"/exo.conf\"";
        description = "Path of the generated fragment, relative to the XDG config home.";
      };

      sources = mkOption {
        type = types.listOf types.str;
        default = [
          "colors.conf"
        ];
        description = "Files the fragment sources, for example Matugen's colours.";
      };

      variables = mkOption {
        type = types.attrsOf variableModule;
        default = {
          terminal = {
            name = "$terminal";
            value = exo.terminal.name;
          };
          fileManager = {
            name = "$fileManager";
            value = exo.fileManager.name;
          };
          launcher = {
            name = "$menu";
            value = exo.commands.launcher;
          };
        };
        description = "Variables the fragment defines and its bindings can use.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = exo.sessionVariables;
        description = "Variables exported to every window by the fragment.";
      };

      bindings = mkOption {
        type = types.attrsOf types.str;
        default = {
          terminal = "$mainMod, T, exec, ${cfg.hyprland.variables.terminal.name}";
          file_manager = "$mainMod, E, exec, ${cfg.hyprland.variables.fileManager.name}";
          launcher = "$mainMod, R, exec, ${cfg.hyprland.variables.launcher.name}";
          settings = "$mainMod SHIFT, W, exec, ${exo.commands.settings}";
          power_menu = "$mainMod, Escape, exec, ${exo.commands.powerMenu}";
          lock = "$mainMod, L, exec, ${exo.commands.lock}";
        };
        description = "Key bindings written as `bind = <value>` lines.";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Raw Hyprland text appended to the fragment.";
      };
    };

    niri = {
      directory = mkOption {
        type = types.str;
        default = "niri";
        description = "Directory below the XDG config home for the generated fragment.";
      };

      fileName = mkOption {
        type = types.str;
        default = "${cfg.niri.directory}/exo.kdl";
        defaultText = "exo.compositor.niri.directory + \"/exo.kdl\"";
        description = "Path of the generated fragment, relative to the XDG config home.";
      };

      wrapBindings = mkOption {
        type = types.bool;
        default = true;
        description = "Wrap exo.compositor.niri.bindings in a `binds { … }` block.";
      };

      bindings = mkOption {
        type = types.lines;
        default = ''
          Mod+T { spawn "${exo.terminal.name}"; }
          Mod+D { spawn "${exo.commands.launcher}"; }
          Mod+L { spawn "${exo.commands.lock}"; }
          Mod+E { spawn "${exo.fileManager.name}"; }
          Mod+Escape { spawn "${exo.commands.powerMenu}"; }
          Mod+I { spawn "${exo.commands.settings}"; }
          Mod+A { spawn "${exo.commands.quickCenter}"; }
        '';
        description = "Raw Niri bindings written into the fragment.";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Raw Niri text appended to the fragment.";
      };
    };
  };

  config = mkIf exo.enable {
    assertions = [
      {
        assertion = cfg.type == "none" || cfg.enable;
        message = "Set exo.compositor.enable = true when selecting a compositor type.";
      }
      {
        assertion = cfg.type == "none" || elem cfg.type (attrNames cfg);
        message = "exo.compositor.type must name one of the compositor option sets: ${concatStringsSep ", " (attrNames cfg)}.";
      }
    ];

    xdg.config.files = mkIf (cfg.enable && cfg.type != "none") {
      "${selected.fileName}" = {
        text = renderers.${cfg.type} (selected // {inherit (cfg) autostart;});
        clobber = cfg.overwrite;
      };
    };
  };
}
