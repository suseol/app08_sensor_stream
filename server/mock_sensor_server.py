"""LAB08 수업용 모의 서버. 인증 없는 로컬 실습용이며 공개 배포하지 않습니다."""
from __future__ import annotations

import argparse
import asyncio
import contextlib
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import uuid
from typing import Any

from aiohttp import web, WSMsgType


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


@dataclass
class Room:
    boot_id: str
    name: str = "room01"
    sequence: int = 0
    temperature: float = 25.0
    humidity: float = 50.0
    device_on: bool = False
    pulse_offset: float = 0.0
    recorded_at: str = field(default_factory=utc_now)
    clients: set[web.WebSocketResponse] = field(default_factory=set)
    http_requests: int = 0
    socket_connections: int = 0
    commands: int = 0
    sent_telemetry: int = 0
    paused: bool = False
    reject_next: bool = False
    delay_next: float = 0.0
    drop_next_ack: bool = False
    pending: set[asyncio.Task[Any]] = field(default_factory=set)

    def __post_init__(self) -> None:
        # 첫 REST 조회부터 방마다 값이 다르게 보이도록 시작 온도를 지정합니다.
        self.temperature = self.pattern_temperature()

    def pattern_temperature(self) -> float:
        # room01: 천천히 오르내리는 방 / room02: 급격히 오르내리는 방
        # room03: 일정 시간 유지하다가 바뀌는 방
        if self.name == "room02":
            return 20.5 if (self.sequence // 5) % 2 == 0 else 30.5
        if self.name == "room03":
            return (22.0, 26.0, 29.0, 24.0)[(self.sequence // 8) % 4]
        return 25.0 + 2.5 * math.sin(self.sequence / 6)

    def snapshot(self) -> dict[str, Any]:
        return {
            "type": "telemetry", "bootId": self.boot_id,
            "sequence": self.sequence, "recordedAt": self.recorded_at,
            "temperature": round(self.temperature, 2),
            "humidity": round(self.humidity, 2), "deviceOn": self.device_on,
        }

    def advance(self, *, pulse: bool = False) -> None:
        self.sequence += 1
        self.recorded_at = utc_now()
        if pulse:
            # 제어판에서 즉시 +5°C를 보여 주고, 이후 천천히 원래 패턴으로 복귀
            self.pulse_offset += 5.0
            self.temperature += 5.0
        else:
            self.pulse_offset *= 0.82
            self.temperature = (self.pattern_temperature() + self.pulse_offset
                                - (1.5 if self.device_on else 0.0))
        self.humidity = 50 + 5 * math.sin(self.sequence / 7)


ROOMS = web.AppKey("rooms", dict)
BOOT = web.AppKey("boot", str)
INTERVAL = web.AppKey("interval", float)


def get_room(request: web.Request) -> Room:
    name = request.query.get("room", "room01")
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", name):
        raise web.HTTPBadRequest(text="room: 영문, 숫자, _, -만 1~32자로 입력하세요.")
    rooms = request.app[ROOMS]
    if name not in rooms:
        if len(rooms) >= 500:
            raise web.HTTPServiceUnavailable(text="수업용 room 한도를 초과했습니다.")
        rooms[name] = Room(boot_id=request.app[BOOT], name=name)
    return rooms[name]


@web.middleware
async def cors(request: web.Request, handler):
    # Flutter Web 실습을 위한 설정입니다. 인증과 운영용 접근 제어가 아닙니다.
    if request.method == "OPTIONS":
        response = web.Response(status=204)
    else:
        try:
            response = await handler(request)
        except web.HTTPException as exc:
            response = web.Response(status=exc.status, text=exc.text, headers=exc.headers)
    if not response.prepared:
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
        response.headers["Cache-Control"] = "no-store"
    return response


async def broadcast(room: Room, *, raw: str | None = None) -> None:
    if room.paused and raw is None:
        return
    payload = raw if raw is not None else json.dumps(room.snapshot(), ensure_ascii=False)
    async def send(ws: web.WebSocketResponse) -> None:
        try:
            await asyncio.wait_for(ws.send_str(payload), timeout=1)
            if raw is None:
                room.sent_telemetry += 1
        except (ConnectionError, RuntimeError, asyncio.TimeoutError):
            room.clients.discard(ws)
            with contextlib.suppress(Exception):
                await ws.close()
    if room.clients:
        await asyncio.gather(*(send(ws) for ws in tuple(room.clients)))


async def health(request: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "bootId": request.app[BOOT]})


async def snapshot(request: web.Request) -> web.Response:
    room = get_room(request)
    room.http_requests += 1
    return web.json_response(room.snapshot())


async def stats(request: web.Request) -> web.Response:
    room = get_room(request)
    return web.json_response({
        "httpSnapshotRequests": room.http_requests,
        "totalSocketConnections": room.socket_connections,
        "activeSockets": len(room.clients), "deviceCommands": room.commands,
        "sentTelemetryFrames": room.sent_telemetry,
        "paused": room.paused, "snapshot": room.snapshot(),
    })


async def scenario(request: web.Request) -> web.Response:
    room = get_room(request)
    try:
        data = await request.json()
    except (ValueError, UnicodeDecodeError):
        raise web.HTTPBadRequest(text="JSON 객체가 필요합니다.")
    if not isinstance(data, dict):
        raise web.HTTPBadRequest(text="JSON 객체가 필요합니다.")
    action = data.get("action")
    if action == "pulse":
        room.advance(pulse=True)
        await broadcast(room)
    elif action == "bad_json":
        await broadcast(room, raw="{not-valid-json")
    elif action == "disconnect":
        sockets = tuple(room.clients)
        await asyncio.gather(*(ws.close(code=1012, message=b"Lab disconnect") for ws in sockets))
    elif action == "pause":
        room.paused = True
    elif action == "resume":
        room.paused = False
        room.advance()
        await broadcast(room)
    elif action == "reject_next":
        room.reject_next = True
    elif action == "delay_ack":
        seconds = data.get("seconds", 5)
        if isinstance(seconds, bool) or not isinstance(seconds, (int, float)) or not 0 <= seconds <= 10:
            raise web.HTTPBadRequest(text="seconds는 0~10 사이의 숫자여야 합니다.")
        room.delay_next = float(seconds)
    elif action == "drop_ack":
        room.drop_next_ack = True
    elif action == "reset_stats":
        room.http_requests = room.socket_connections = room.commands = room.sent_telemetry = 0
    else:
        raise web.HTTPBadRequest(text="지원하지 않는 시나리오입니다.")
    return web.json_response({"ok": True, "action": action})


async def process_command(room: Room, ws: web.WebSocketResponse, raw: str) -> None:
    try:
        data = json.loads(raw)
    except ValueError:
        await ws.send_json({"type": "error", "message": "유효한 JSON이 필요합니다."})
        return
    if not isinstance(data, dict):
        await ws.send_json({"type": "error", "message": "명령은 JSON 객체여야 합니다."})
        return
    command_id = data.get("commandId")
    if (data.get("type") != "set_device" or type(data.get("on")) is not bool or
        not isinstance(command_id, str) or not 1 <= len(command_id) <= 80):
        await ws.send_json({"type": "error", "message": "명령 필드와 타입을 확인하세요."})
        return
    room.commands += 1
    rejected = room.reject_next
    delay = room.delay_next
    dropped = room.drop_next_ack
    room.reject_next = False
    room.delay_next = 0
    room.drop_next_ack = False
    if not rejected:
        # toggle이 아니라 최종 목표 상태를 적용합니다.
        room.device_on = data["on"]
        room.advance()
        await broadcast(room)
    ack = {
        "type": "ack", "commandId": command_id, "ok": not rejected,
        "deviceOn": room.device_on,
        "message": "수업용 거절 시나리오" if rejected else "적용 완료",
    }
    if dropped:
        return
    async def send_ack():
        if delay:
            await asyncio.sleep(delay)
        if not ws.closed:
            with contextlib.suppress(ConnectionError, RuntimeError):
                await ws.send_json(ack)
    task = asyncio.create_task(send_ack())
    room.pending.add(task)
    task.add_done_callback(room.pending.discard)


async def websocket(request: web.Request) -> web.WebSocketResponse:
    room = get_room(request)
    ws = web.WebSocketResponse(max_msg_size=16 * 1024, heartbeat=20)
    await ws.prepare(request)
    room.clients.add(ws)
    room.socket_connections += 1
    try:
        # 전송 중단 시나리오에서는 새 연결에도 센서 프레임을 주지 않습니다.
        if not room.paused:
            await ws.send_json(room.snapshot())
            room.sent_telemetry += 1
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                await process_command(room, ws, msg.data)
            elif msg.type == WSMsgType.ERROR:
                break
    except (ConnectionError, RuntimeError):
        pass
    finally:
        room.clients.discard(ws)
    return ws


async def index(request: web.Request) -> web.Response:
    path = Path(__file__).with_name("control.html")
    return web.Response(text=path.read_text(encoding="utf-8"), content_type="text/html")


async def shutdown(app: web.Application):
    # HTTP 요청 종료를 기다리기 전에 열린 WebSocket부터 닫습니다.
    for room in app[ROOMS].values():
        await asyncio.gather(*(ws.close(code=1001, message=b"Server shutdown")
                               for ws in tuple(room.clients)))


async def runtime(app: web.Application):
    async def ticker():
        while True:
            await asyncio.sleep(app[INTERVAL])
            rooms = tuple(app[ROOMS].values())
            for room in rooms:
                room.advance()
            await asyncio.gather(*(broadcast(room) for room in rooms))
    task = asyncio.create_task(ticker())
    yield
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task
    for room in app[ROOMS].values():
        for pending in tuple(room.pending):
            pending.cancel()
        await asyncio.gather(*tuple(room.pending), return_exceptions=True)
        await asyncio.gather(*(ws.close() for ws in tuple(room.clients)))


def create_app(interval: float = 1.0) -> web.Application:
    if interval <= 0:
        raise ValueError("interval must be positive")
    app = web.Application(middlewares=[cors], client_max_size=16 * 1024)
    app[ROOMS] = {}
    app[BOOT] = uuid.uuid4().hex[:12]
    app[INTERVAL] = interval
    app.on_shutdown.append(shutdown)
    app.cleanup_ctx.append(runtime)
    app.add_routes([
        web.get("/", index), web.get("/health", health),
        web.get("/api/snapshot", snapshot), web.get("/api/stats", stats),
        web.post("/api/scenario", scenario), web.get("/ws", websocket),
    ])
    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--interval", type=float, default=1.0)
    args = parser.parse_args()
    print("로컬 실습 전용입니다. 공개 인터넷에 포트를 개방하지 마세요.")
    print(f"제어판: http://127.0.0.1:{args.port}/")
    web.run_app(create_app(args.interval), host=args.host, port=args.port)
