import os
import shutil

from ignis import utils
from ignis.app import IgnisApp
from ignis.options_manager import OptionsGroup, OptionsManager, TrackedList
from ignis.window_manager import WindowManager
from config_paths import config_path, state_path

window_manager = WindowManager.get_default()
app = IgnisApp.get_initialized()

# Where the shell keeps its writable copy: the configuration directory can be a
# read-only Nix store link, so state lives in XDG_STATE_HOME instead.
settings_file = state_path("exo", "user_settings.json")

# Optional seed written by the Nix module, used only on the first start.
seed_file = config_path("ignis", "user_settings.json")


def seed_settings() -> None:
    """Create the writable settings file from the Nix seed when it is missing."""

    if not os.path.exists(seed_file):
        return
    if os.path.exists(settings_file) and os.environ.get(
        "EXO_RESET_USER_SETTINGS"
    ) not in ("1", "true", "yes"):
        return

    os.makedirs(os.path.dirname(settings_file), exist_ok=True)
    shutil.copyfile(seed_file, settings_file)


class UserSettings(OptionsManager):
    def __init__(self):
        seed_settings()
        super().__init__(file=settings_file)

    class Appearance(OptionsGroup):
        class WallpaperColors(OptionsGroup):
            # Wallpaper / Colours
            quickselect_path: str = ""
            wallpaper_path: str = ""
            color_scheme: str = "tonal_spot"
            dark_mode: bool = True

            class AutoDark(OptionsGroup):
                enabled: bool = False
                start_hour: int = 22
                start_min: int = 0
                end_hour: int = 6
                end_min: int = 0

            auto_dark = AutoDark()

        wallcolors = WallpaperColors()

    class Interface(OptionsGroup):
        class Modules(OptionsGroup):
            class Locations(OptionsGroup):
                launcher: int = 0
                window_info: int = 0
                media: int = 0
                workspaces: int = 1
                tasks: int = 1
                recording_indicator: int = 2
                systeminfotray: int = 2
                clock: int = 2

            class Visibility(OptionsGroup):
                window_info: bool = True
                media: bool = True
                workspaces: bool = True
                recording_indicator: bool = True
                systeminfotray: bool = True
                clock: bool = True
                tasks: bool = False
                launcher: bool = False

            class BarID(OptionsGroup):
                launcher: int = 0
                window_info: int = 0
                media: int = 0
                workspaces: int = 0
                tasks: int = 0
                recording_indicator: int = 0
                systeminfotray: int = 0
                clock: int = 0

            class ModuleOptions(OptionsGroup):
                show_date: bool = True
                day_month_swapped: bool = False
                military_time: bool = False
                recording_indicator: str = "recording"
                workspaces_style: str = "numbers"
                fixed_workspaces_enabled: bool = True
                fixed_workspaces_amount: int = 5

            location = Locations()
            visibility = Visibility()
            bar_id = BarID()
            options = ModuleOptions()

        class Bar(OptionsGroup):
            side: str = "bottom"
            vertical: bool = False
            density: int = 0
            floating: bool = False
            separation: bool = False
            centered: bool = False
            bar_background: bool = True
            module_backgrounds: bool = True

        class Bar2(OptionsGroup):
            enabled: bool = True
            side: str = "top"
            vertical: bool = False
            density: int = 0
            floating: bool = False
            separation: bool = False
            centered: bool = False
            bar_background: bool = True
            module_backgrounds: bool = True

        class Notifications(OptionsGroup):
            anchor: list = ["top", "right"]
            compact_popup: bool = False

        class Launcher(OptionsGroup):
            layout: str = "grid"

        class Misc(OptionsGroup):
            shell_corners: bool = True
            screen_corners: str = "not_fullscreen"

        modules = Modules()
        bar = Bar()
        bar2 = Bar2()
        notifications = Notifications()
        launcher = Launcher()
        misc = Misc()

    class Services(OptionsGroup):
        class Recorder(OptionsGroup):
            start_notification: bool = True
            stop_notification: bool = True
            record_audio: bool = True

        class OSD(OptionsGroup):
            anchor: list = ["bottom", "right"]
            vertical: bool = False

        recorder = Recorder()
        osd = OSD()

    appearance = Appearance()
    interface = Interface()
    services = Services()


user_settings = UserSettings()
