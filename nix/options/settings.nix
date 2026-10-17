{
  lib,
  types,
}: let
  inherit (lib) mkOption;

  mkBool = default:
    mkOption {
      type = types.bool;
      inherit default;
    };

  mkInt = default:
    mkOption {
      type = types.int;
      inherit default;
    };

  mkString = default:
    mkOption {
      type = types.str;
      inherit default;
    };

  mkStringList = default:
    mkOption {
      type = types.listOf types.str;
      inherit default;
    };
in {
  options = {
    appearance.wallcolors = {
      quickselect_path = mkString "";
      wallpaper_path = mkString "";
      color_scheme = mkOption {
        type = types.enum [
          "content"
          "expressive"
          "fidelity"
          "fruit-salad"
          "monochrome"
          "neutral"
          "rainbow"
          "tonal-spot"
          "tonal_spot"
        ];
        default = "tonal_spot";
      };
      dark_mode = mkBool true;

      auto_dark = {
        enabled = mkBool false;
        start_hour = mkOption {
          type = types.ints.between 0 23;
          default = 22;
        };
        start_min = mkOption {
          type = types.ints.between 0 59;
          default = 0;
        };
        end_hour = mkOption {
          type = types.ints.between 0 23;
          default = 6;
        };
        end_min = mkOption {
          type = types.ints.between 0 59;
          default = 0;
        };
      };
    };

    interface.modules = {
      location = {
        launcher = mkInt 0;
        window_info = mkInt 0;
        media = mkInt 0;
        workspaces = mkInt 1;
        tasks = mkInt 1;
        recording_indicator = mkInt 2;
        systeminfotray = mkInt 2;
        clock = mkInt 2;
      };

      visibility = {
        window_info = mkBool true;
        media = mkBool true;
        workspaces = mkBool true;
        recording_indicator = mkBool true;
        systeminfotray = mkBool true;
        clock = mkBool true;
        tasks = mkBool false;
        launcher = mkBool false;
      };

      bar_id = {
        launcher = mkInt 0;
        window_info = mkInt 0;
        media = mkInt 0;
        workspaces = mkInt 0;
        tasks = mkInt 0;
        recording_indicator = mkInt 0;
        systeminfotray = mkInt 0;
        clock = mkInt 0;
      };

      options = {
        show_date = mkBool true;
        day_month_swapped = mkBool false;
        military_time = mkBool false;
        recording_indicator = mkString "recording";
        workspaces_style = mkString "numbers";
        fixed_workspaces_enabled = mkBool true;
        fixed_workspaces_amount = mkInt 5;
      };
    };

    interface.bar = {
      side = mkOption {
        type = types.enum ["top" "bottom" "left" "right"];
        default = "bottom";
      };
      vertical = mkBool false;
      density = mkInt 0;
      floating = mkBool false;
      separation = mkBool false;
      centered = mkBool false;
      bar_background = mkBool true;
      module_backgrounds = mkBool true;
    };

    interface.bar2 = {
      enabled = mkBool true;
      side = mkOption {
        type = types.enum ["top" "bottom" "left" "right"];
        default = "top";
      };
      vertical = mkBool false;
      density = mkInt 0;
      floating = mkBool false;
      separation = mkBool false;
      centered = mkBool false;
      bar_background = mkBool true;
      module_backgrounds = mkBool true;
    };

    interface.notifications = {
      anchor = mkStringList ["top" "right"];
      compact_popup = mkBool false;
    };

    interface.launcher = {
      layout = mkOption {
        type = types.enum ["grid" "list"];
        default = "grid";
      };
    };

    interface.misc = {
      shell_corners = mkBool true;
      screen_corners = mkOption {
        type = types.enum ["always" "not_fullscreen" "never"];
        default = "not_fullscreen";
      };
    };

    services.recorder = {
      start_notification = mkBool true;
      stop_notification = mkBool true;
      record_audio = mkBool true;
    };

    services.osd = {
      anchor = mkStringList ["bottom" "right"];
      vertical = mkBool false;
    };
  };

  toJSON = settings: {
    appearance = {
      wallcolors = {
        inherit
          (settings.appearance.wallcolors)
          quickselect_path
          wallpaper_path
          color_scheme
          dark_mode
          ;
        auto_dark = settings.appearance.wallcolors.auto_dark;
      };
    };

    interface = {
      modules = settings.interface.modules;
      bar = settings.interface.bar;
      bar2 = settings.interface.bar2;
      notifications = settings.interface.notifications;
      launcher = settings.interface.launcher;
      misc = settings.interface.misc;
    };

    services = {
      recorder = settings.services.recorder;
      osd = settings.services.osd;
    };
  };
}
