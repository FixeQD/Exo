def optional_service(module, name):
    try:
        return getattr(__import__(module, fromlist=[name]), name)
    except Exception:  # noqa: BLE001 - any failure means "service unavailable"
        return None


def get_network_service():
    return _service("ignis.services.network", "NetworkService")


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
