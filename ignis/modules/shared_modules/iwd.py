import asyncio

from gi.repository import Gio, GLib, GObject

BUS_NAME = "net.connman.iwd"
MANAGER_PATH = "/net/connman/iwd"

ADAPTER_INTERFACE = "net.connman.iwd.Adapter"
DEVICE_INTERFACE = "net.connman.iwd.Device"
STATION_INTERFACE = "net.connman.iwd.Station"
NETWORK_INTERFACE = "net.connman.iwd.Network"

CHANGED = GObject.SignalFlags.RUN_FIRST, None, ()


def _proxy(bus, path, interface):
    """A proxy for `path` implementing `interface`, or `None`."""

    try:
        return Gio.DBusProxy.new_sync(
            bus,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START,
            None,
            BUS_NAME,
            path,
            interface,
            None,
        )
    except (GLib.Error, TypeError):
        return None


def _children(bus, path):
    """Child object paths of `path`, discovered through Introspect."""

    proxy = _proxy(bus, path, "org.freedesktop.DBus.Introspectable")
    reply = proxy.call_sync(
        "Introspect", None, Gio.DBusCallFlags.NONE, -1, None
    )
    node = Gio.DBusNodeInfo.new_for_xml(reply.unpack()[0])
    return [f"{path.rstrip('/')}/{child.path.lstrip('/')}" for child in node.nodes]


def _get(proxy, name):
    reply = proxy.call_sync(
        "org.freedesktop.DBus.Properties.Get",
        GLib.Variant("(ss)", (proxy.get_interface_name(), name)),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    return reply.unpack()[0]


def _set(proxy, name, variant):
    proxy.call_sync(
        "org.freedesktop.DBus.Properties.Set",
        GLib.Variant("(ssv)", (proxy.get_interface_name(), name, variant)),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )


async def _call(proxy, method):
    """Await a D-Bus method call, off the UI thread."""

    def send():
        return proxy.call_sync(
            method, None, Gio.DBusCallFlags.NONE, -1, None
        ).unpack()

    return await asyncio.to_thread(send)


class IwdAccessPoint:
    def __init__(self, device, path, ssid, network_type, connected, level):
        self._device = device
        self.path = path
        self.ssid = ssid
        self.type = network_type
        self.security = "" if network_type in ("", "open") else network_type
        self.is_connected = connected
        # iwd reports a negative value while the signal level is unknown.
        self.strength = max(level, 0) if level is not None else 0

    async def connect_to_graphical(self):
        if not self._device.is_saved(self.path):
            self._device.report_unsaved(self.ssid)
            return

        proxy = _proxy(self._device.bus, self.path, NETWORK_INTERFACE)
        if proxy is not None:
            await _call(proxy, "Connect")

    async def disconnect_from(self):
        await _call(self._device.station, "Disconnect")


class IwdDevice:
    def __init__(self, bus, path):
        self.bus = bus
        self.path = path
        self.station = _proxy(bus, path, STATION_INTERFACE)
        self.device = _proxy(bus, path, DEVICE_INTERFACE)
        if self.station is None or self.device is None:
            raise RuntimeError(f"not a station: {path}")

    def is_saved(self, network_path):
        """Whether iwd already knows the passphrase for this network."""

        proxy = _proxy(self.bus, network_path, NETWORK_INTERFACE)
        if proxy is None:
            return False
        try:
            return _get(proxy, "KnownNetwork") not in (None, "/")
        except GLib.Error:
            return False

    def report_unsaved(self, ssid):
        from scripts import send_notification

        send_notification(
            "Network not saved",
            f'Save "{ssid}" once with "iwctl", then connect it from Exo.',
        )

    @property
    def access_points(self):
        reply = self.station.call_sync(
            "GetOrderedNetworks", None, Gio.DBusCallFlags.NONE, -1, None
        )

        points = []
        for path, level in reply.unpack()[0]:
            try:
                proxy = _proxy(self.bus, path, NETWORK_INTERFACE)
                if proxy is None:
                    continue
                points.append(
                    IwdAccessPoint(
                        device=self,
                        path=path,
                        ssid=_get(proxy, "Name") or "",
                        network_type=_get(proxy, "Type") or "open",
                        connected=bool(_get(proxy, "Connected")),
                        level=level,
                    )
                )
            except GLib.Error:
                continue
        return points

    @property
    def ap(self):
        for point in self.access_points:
            if point.is_connected:
                return point
        return None

    async def scan(self):
        try:
            await _call(self.station, "Scan")
        except RuntimeError:
            pass
        await asyncio.sleep(2)


class IwdWifi(GObject.Object):
    __gsignals__ = {"changed": CHANGED}

    def __init__(self, bus, adapter):
        super().__init__()
        self.bus = bus
        self.adapter = adapter
        self.devices = []
        self._enabled = False
        self._connected = False

    @property
    def enabled(self):
        return self._enabled

    @enabled.setter
    def enabled(self, active):
        try:
            _set(self.adapter, "Powered", GLib.Variant("b", bool(active)))
        except GLib.Error:
            pass
        self.refresh()

    @property
    def is_connected(self):
        return self._connected

    def refresh(self):
        try:
            powered = bool(_get(self.adapter, "Powered"))
        except GLib.Error:
            powered = False

        devices = []
        for path in _children(self.bus, self.adapter.get_object_path()):
            try:
                devices.append(IwdDevice(self.bus, path))
            except (GLib.Error, RuntimeError):
                continue

        connected = any(device.ap is not None for device in devices)
        if powered != self._enabled or connected != self._connected:
            self._enabled = powered
            self._connected = connected
            self.devices = devices
            self.emit("changed")


class IwdWired(GObject.Object):
    __gsignals__ = {"changed": CHANGED}

    def __init__(self):
        super().__init__()
        self._connected = False

    @property
    def is_connected(self):
        return self._connected

    def update(self, connected):
        if connected != self._connected:
            self._connected = connected
            self.emit("changed")


class IwdNetworkService:
    def __init__(self, bus):
        self.bus = bus
        self.adapter = self._find_adapter()
        if self.adapter is None:
            raise RuntimeError("no iwd adapter")

        self.wifi = IwdWifi(bus, self.adapter)
        self.ethernet = IwdWired()
        self.vpn = IwdWired()
        self._task = None
        self.refresh()

    def _find_adapter(self):
        for path in _children(self.bus, MANAGER_PATH):
            proxy = _proxy(self.bus, path, ADAPTER_INTERFACE)
            if proxy is not None:
                return proxy
        return None

    def start(self):
        """Keep the exposed state in sync with iwd."""

        if self._task is None:
            try:
                self._task = asyncio.ensure_future(self._poll())
            except RuntimeError:
                self._task = None

    async def _poll(self):
        while True:
            try:
                self.refresh()
            except Exception:  # noqa: BLE001 - a D-Bus hiccup must not stop polling
                pass
            await asyncio.sleep(5)

    def refresh(self):
        self.wifi.refresh()
        connected = [
            ap for device in self.wifi.devices for ap in device.access_points
        ]
        self.ethernet.update(
            any(ap.is_connected and ap.type == "wired" for ap in connected)
        )
        self.vpn.update(False)


def get_iwd_network_service():
    """Return an IwdNetworkService, or `None` when iwd is not reachable."""

    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        return IwdNetworkService(bus)
    except (GLib.Error, RuntimeError):
        return None
