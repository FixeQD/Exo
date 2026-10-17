import os


def config_home() -> str:
    return os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config"))


def state_home() -> str:
    return os.path.expanduser(
        os.environ.get("XDG_STATE_HOME", "~/.local/state")
    )


def config_path(*parts: str) -> str:
    return os.path.join(config_home(), *parts)


def state_path(*parts: str) -> str:
    return os.path.join(state_home(), *parts)
