import os


def optional_service(module, name):
    try:
        return getattr(__import__(module, fromlist=[name]), name)
    except Exception:  # noqa: BLE001 - any failure means "service unavailable"
        return None


def get_network_service():
    backend = os.environ.get("EXO_NETWORK_BACKEND", "auto").strip().lower()

    if backend == "none":
        return None

    if backend != "iwd":
        service = _service("ignis.services.network", "NetworkService")
        if service is not None:
            return service
        if backend == "networkmanager":
            return None

    from modules.shared_modules.iwd import get_iwd_network_service

    return get_iwd_network_service()


def watch(service, callback):
    if hasattr(service, "connect"):
        try:
            service.connect("changed", callback)
            return
        except (TypeError, AttributeError):
            pass

    for prop in ("enabled", "is-connected"):
        service.connect(f"notify::{prop}", callback)


def get_bluetooth_service():
    return _service("ignis.services.bluetooth", "BluetoothService")


def get_audio_service():
    return _service("ignis.services.audio", "AudioService")


def get_backlight_service():
    return _service("ignis.services.backlight", "BacklightService")


def get_upower_service():
    return _service("ignis.services.upower", "UPowerService")


def _service(module, name):
    service = optional_service(module, name)
    if service is None:
        return None

    try:
        return service.get_default()
    except Exception:  # noqa: BLE001 - the service can fail at runtime too
        return None
