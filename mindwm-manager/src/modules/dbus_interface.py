#!/usr/bin/env python3
import sys
import os
import functools

sys.path.append(os.path.abspath(os.path.dirname(__file__) + '/..'))

from dbus_next.service import ServiceInterface, method, signal, dbus_property
from dbus_next.aio.message_bus import MessageBus
from dbus_next.constants import BusType
from dbus_next import Variant

import asyncio

# credits to https://blog.dalibo.com/2022/09/12/monitoring-python-subprocesses.html
class MyProtocol(asyncio.subprocess.SubprocessStreamProtocol):
    def __init__(self, reader, limit, loop):
        super().__init__(limit=limit, loop=loop)
        self._reader = reader

    def pipe_data_received(self, fd, data):
        """Called when the child process writes data into its stdout
        or stderr pipe.
        """
        super().pipe_data_received(fd, data)
        if fd == 1:
            self._reader.feed_data(data)

        if fd == 2:
            self._reader.feed_data(data)

    def pipe_connection_lost(self, fd, exc):
        """Called when one of the pipes communicating with the child
        process is closed.
        """
        super().pipe_connection_lost(fd, exc)
        if fd == 1:
            if exc:
                self._reader.set_exception(exc)
            else:
                self._reader.feed_eof()

        if fd == 2:
            if exc:
                self._reader.set_exception(exc)
            else:
                self._reader.feed_eof()

class Subprocess():
    def __init__(self, cmd, callback):
        self._loop = asyncio.get_event_loop()
        self._cmd = cmd.split()
        self._callback = callback

    async def start(self):
        self._reader = asyncio.StreamReader(loop=self._loop)
        protocol_factory = functools.partial(
            MyProtocol, self._reader, limit=2**16, loop=self._loop
        )

        transport, protocol = await self._loop.subprocess_exec(
            protocol_factory,
            *self._cmd,
            stdin = asyncio.subprocess.PIPE,
            stdout = asyncio.subprocess.PIPE,
            stderr = asyncio.subprocess.PIPE)

        proc = asyncio.subprocess.Process(transport, protocol, self._loop)
        (out, err), _ = await asyncio.gather(proc.communicate(), self.callback_on_output())

    async def callback_on_output(self):
        async for line in self._reader:
            self._callback(line, 'stdout')


class ManagerInterface(ServiceInterface):
    def __init__(self, name):
        super().__init__(name)
        self._string_prop = 'kevin'

    @signal()
    def callback_signal1(self, output, label) -> 's':
        print(f"callback signal: {label}: {output}")
        return output.decode("utf-8")

    @method()
    async def Run(self, cmd: 's', uid: 'i') -> 's':
        self._subp1 = Subprocess(cmd, self.callback_signal1)
        await self._subp1.start()
        print(f"echo: ({uid}) {cmd}")
        return 'started'

    @method()
    def Echo(self, what: 's') -> 's':
        print(f"echo: {what}")
        return what

    @method()
    def EchoMultiple(self, what1: 's', what2: 's') -> 'ss':
        return [what1, what2]

    @method()
    def GetVariantDict(self) -> 'a{sv}':
        return {
            'foo': Variant('s', 'bar'),
            'bat': Variant('x', -55),
            'a_list': Variant('as', ['hello', 'world'])
        }

    @dbus_property(name='StringProp')
    def string_prop(self) -> 's':
        print("string prop")
        return self._string_prop

    @string_prop.setter
    def string_prop_setter(self, val: 's'):
        self._string_prop = val

    @signal()
    def signal_simple(self) -> 's':
        return 'hello'

    @signal()
    def signal_multiple(self) -> 'ss':
        return ['hello', 'world']


async def main():
    name = 'org.mindwm'
    path = '/manager'
    interface_name = 'mindwm.client'

    bus = await MessageBus(bus_type = BusType.SESSION).connect()
    interface = ManagerInterface(interface_name)
    bus.export(path, interface)
    await bus.request_name(name)
    print(f'service up on name: "{name}", path: "{path}", interface: "{interface_name}"')
    await bus.wait_for_disconnect()


asyncio.get_event_loop().run_until_complete(main())
