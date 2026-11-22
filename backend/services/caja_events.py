"""
Bus de eventos en tiempo real (Server-Sent Events) para el Módulo de Caja.

Permite notificar al instante (<1s) a las terminales de Caja de una sucursal
cuando se crea o anula una orden, se genera un backorder o se registra/edita un pago,
sin dependencias externas y con seguridad entre hilos (endpoints sync -> loop async).
"""

import asyncio
import json
import threading
import time
from collections import defaultdict
from typing import Dict, Optional, Set, Tuple

Subscriber = Tuple[asyncio.AbstractEventLoop, asyncio.Queue]


class CajaEventBus:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._subscribers: Dict[int, Set[Subscriber]] = defaultdict(set)

    def subscribe(self, sucursal_id: int) -> Tuple[asyncio.Queue, Subscriber]:
        loop = asyncio.get_running_loop()
        queue: asyncio.Queue = asyncio.Queue(maxsize=32)
        sub: Subscriber = (loop, queue)
        with self._lock:
            self._subscribers[sucursal_id].add(sub)
        return queue, sub

    def unsubscribe(self, sucursal_id: int, sub: Subscriber) -> None:
        with self._lock:
            subs = self._subscribers.get(sucursal_id)
            if subs:
                subs.discard(sub)
                if not subs:
                    self._subscribers.pop(sucursal_id, None)

    def subscriber_count(self, sucursal_id: Optional[int] = None) -> int:
        with self._lock:
            if sucursal_id is not None:
                return len(self._subscribers.get(sucursal_id, ()))
            return sum(len(s) for s in self._subscribers.values())

    @staticmethod
    def _safe_enqueue(queue: asyncio.Queue, message: str) -> None:
        if queue.full():
            try:
                queue.get_nowait()
            except asyncio.QueueEmpty:
                pass
        try:
            queue.put_nowait(message)
        except asyncio.QueueFull:
            pass

    def publish(self, sucursal_id: Optional[int], event_type: str, extra: Optional[dict] = None) -> None:
        """
        Publica un evento no bloqueante para todos los clientes SSE conectados
        a `sucursal_id`. Seguro para invocarse desde endpoints síncronos o asíncronos.
        """
        if sucursal_id is None:
            return

        with self._lock:
            targets = list(self._subscribers.get(sucursal_id, ()))

        if not targets:
            return

        payload = {
            "event": event_type,
            "sucursal_id": sucursal_id,
            "ts": int(time.time() * 1000),
        }
        if extra:
            payload.update(extra)

        message = f"event: {event_type}\ndata: {json.dumps(payload)}\n\n"

        for loop, queue in targets:
            try:
                if not loop.is_closed():
                    loop.call_soon_threadsafe(self._safe_enqueue, queue, message)
            except RuntimeError:
                pass


caja_event_bus = CajaEventBus()


def notificar_caja(sucursal_id: Optional[int], event_type: str, extra: Optional[dict] = None) -> None:
    """Helper seguro y no bloqueante para emitir eventos SSE hacia Caja."""
    try:
        caja_event_bus.publish(sucursal_id, event_type, extra=extra)
    except Exception:
        pass
