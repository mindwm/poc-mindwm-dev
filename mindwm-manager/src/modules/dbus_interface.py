#!/usr/bin/env python3
import re
import sys
import os
import functools
from uuid import uuid4

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
    def __init__(self, cmd, output_regex, callback, uid, terminate_callback):
        self._loop = asyncio.get_event_loop()
        self._cmd = cmd.split()
        try:
            if output_regex != "":
                self._output_regex = re.compile(output_regex)
            else:
                self._output_regex = None
        except Exception as e:
            self._output_regex = None

        self._callback = callback
        self._uid = uid
        self._proc = None
        self._terminate_callback = terminate_callback

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
        self._proc = proc
        (out, err), _ = await asyncio.gather(proc.communicate(), self.callback_on_output())
        self._terminate_callback(self._uid)

    async def callback_on_output(self):
        async for line in self._reader:
            if self._output_regex:
                out_string = line.decode('utf-8')
                if self._output_regex.match(out_string):
                    self._callback(self._uid, line, 'stdout')
            else:
                self._callback(self._uid, line, 'stdout')

    async def terminate(self):
        if self._proc:
            self._proc.terminate()

    async def send_stdio(self, string):
        if self._proc:
            s = string + '\n'
            print(f"send to stdio: {s}")
            self._proc.stdin.write(s.encode())


class SpawnedCommand():
    def __init__(self, cmd, output_regex, uid, subprocess):
       self._cmd = cmd
       self._output_regex = output_regex
       self._uid = uid
       self._subp = subprocess


class ManagerInterface(ServiceInterface):
    def __init__(self, name):
        super().__init__(name)
        self._string_prop = 'kevin'
        self._spawned_commands = []
        self._loop = asyncio.get_event_loop()

    def findByUid(self, uid):
        for p in self._spawned_commands:
            if p._uid == uid:
                return p

        return None

    def subp_terminate_callback(self, uid):
        p = self.findByUid(uid)
        if p:
            self._spawned_commands.remove(p)

    @signal()
    def callback_signal(self, uid, output, label) -> 'ss':
        print(f"callback signal: ({uid}) {label}: {output}")
        return [uid, output.decode("utf-8")]

    @method()
    async def Run(self, cmd: 's', output_regex: 's') -> 's':
        uid = str(uuid4())
        subp = Subprocess(
                cmd,
                output_regex,
                self.callback_signal,
                uid,
                self.subp_terminate_callback)
        self._spawned_commands.append(
                SpawnedCommand(
                    cmd, output_regex, uid, subp))
        #await self._subp.start()
        self._loop.create_task(subp.start())
        print(f"echo: ({uid}) {cmd}")
        return uid

    @method()
    async def KillAll(self):
        for p in self._spawned_commands:
            await p._subp.terminate()

        self._spawned_commands.clear()

    @method()
    async def Kill(self, uid: 's'):
        p = self.findByUid(uid)
        if p:
            await p._subp.terminate()
            self._spawned_commands.remove(p)

    @method()
    async def ListSpawned(self) -> 'a(ss)':
        res = []
        for p in self._spawned_commands:
            res.append([p._uid, p._cmd])

        return res

    @method()
    async def SendStdin(self, uid: 's', string: 's'):
        p = self.findByUid(uid)
        if p:
            await p._subp.send_stdio(string)

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
        return self._string_prop

    @string_prop.setter
    def string_prop_setter(self, val: 's'):
        self._string_prop = val

    @signal()
    def feedback_message(self, msg: 's') -> 's':
        return msg

    @signal()
    def signal_multiple(self) -> 'ss':
        return ['hello', 'world']


class DbusInterface():
    def __init__(self):
        pass

    async def init(self):
        self.name = 'org.mindwm.client.manager'
        self.path = '/manager'
        self.interface_name = 'org.mindwm.client'
    
        bus = await MessageBus(bus_type = BusType.SESSION).connect()
        self.interface = ManagerInterface(self.interface_name)
        bus.export(self.path, self.interface)
        await bus.request_name(self.name)
        print(f'service up on name: "{self.name}", path: "{self.path}", interface: "{self.interface_name}"')
        await bus.wait_for_disconnect()

    async def feedback_message(self, msg):
        if self.interface:
            self.interface.feedback_message(msg)

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

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
