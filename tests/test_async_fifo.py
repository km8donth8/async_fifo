import os
import random
from collections import deque
from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, with_timeout


@dataclass(frozen=True)
class AxisBeat:
    data: int
    keep: int
    last: int


def signal_to_int(sig, name):
    assert sig.value.is_resolvable, f"{name} has x/z: {sig.value}"
    return int(sig.value)


COVER = ["saw_full", "saw_empty", "saw_almost_full", "saw_almost_empty", "saw_partial_keep",
         "saw_input_backpressure", "saw_output_backpressure"]
COUNTS = ["input_beats", "output_beats", "input_packets", "output_packets",
          "input_stalls", "output_stalls", "max_queue_depth"]


class State:
    def __init__(self):
        self.expected = deque()  # scoreboard: beats accepted but not yet seen at the output
        for k in COUNTS:
            setattr(self, k, 0)
        for k in COVER:
            setattr(self, k, False)


class AxisSource:
    def __init__(self, dut, state, rng):
        self.dut, self.state, self.rng = dut, state, rng
        self.clock = dut.s_axis_aclk
        self.data_width = len(dut.s_axis_tdata)
        self.keep_width = len(dut.s_axis_tkeep)
        self.full_keep = (1 << self.keep_width) - 1

    def drive(self, valid=0, data=0, keep=0, last=0):
        self.dut.s_axis_tvalid.value = valid
        self.dut.s_axis_tdata.value = data
        self.dut.s_axis_tkeep.value = keep
        self.dut.s_axis_tlast.value = last

    async def send_beat(self, beat, max_gap=0, hold=False):
        for _ in range(self.rng.randint(0, max_gap)):  # idle gap
            await FallingEdge(self.clock)
            self.drive()
        await FallingEdge(self.clock)
        self.drive(1, beat.data, beat.keep, beat.last)
        while True:
            await RisingEdge(self.clock)
            if int(self.dut.s_axis_tready.value):  # handshake (tvalid is always 1 here)
                s = self.state
                s.expected.append(beat)
                s.input_beats += 1
                s.input_packets += beat.last
                s.max_queue_depth = max(s.max_queue_depth, len(s.expected))
                s.saw_partial_keep |= beat.keep != self.full_keep
                break
            self.state.input_stalls += 1
            self.state.saw_input_backpressure = True
        if not hold:  # hold=True keeps tvalid up so the next beat goes out back-to-back
            await FallingEdge(self.clock)
            self.drive()

    def make_data(self, packet_id, beat_id):
        value = self.rng.getrandbits(self.data_width)
        if self.data_width >= 32:  # tag top bits with packet/beat id to ease debugging
            value = (value & ~0xFFFF_FFFF) | ((packet_id & 0xFF) << 24) | ((beat_id & 0xFF) << 16) | self.rng.getrandbits(16)
        return value & ((1 << self.data_width) - 1)

    async def send_packet(self, packet_id, length, max_gap=0):
        for beat_id in range(length):
            last = int(beat_id == length - 1)
            partial = last and self.keep_width > 1 and self.rng.random() < 0.5
            keep = self.rng.randint(1, self.full_keep) if partial else self.full_keep
            beat = AxisBeat(self.make_data(packet_id, beat_id), keep, last)
            await self.send_beat(beat, max_gap, hold=not last)


class AxisSink:
    P_READY = {"off": 0, "always": 1, "random": 0.6, "sparse": 0.1}

    def __init__(self, dut, state, rng):
        self.dut, self.state, self.rng = dut, state, rng
        self.clock = dut.m_axis_aclk
        self.mode = "off"
        self.running = True

    async def ready_driver(self):
        left = val = 0
        while self.running:
            await RisingEdge(self.clock)
            if not signal_to_int(self.dut.m_axis_aresetn, "m_axis_aresetn"):
                self.dut.m_axis_tready.value = 0
                left = 0
                continue
            if self.mode == "bursty":  # runs of ready=1 or ready=0
                if left == 0:
                    val = int(self.rng.random() < 0.55)
                    left = self.rng.randint(1, 20 if val else 30)
                left -= 1
                ready = val
            else:
                ready = int(self.rng.random() < self.P_READY[self.mode])
            self.dut.m_axis_tready.value = ready

    async def monitor(self):
        d, s = self.dut, self.state
        held = None  # beat that was stalled last cycle
        while self.running:
            await FallingEdge(self.clock)  # sample mid-cycle, values are stable for the next rising edge
            await ReadOnly()
            if not signal_to_int(d.m_axis_aresetn, "m_axis_aresetn"):
                held = None
                continue
            valid = signal_to_int(d.m_axis_tvalid, "m_axis_tvalid")
            ready = signal_to_int(d.m_axis_tready, "m_axis_tready")
            cur = None
            if valid:
                cur = AxisBeat(signal_to_int(d.m_axis_tdata, "m_axis_tdata"),
                               signal_to_int(d.m_axis_tkeep, "m_axis_tkeep"),
                               signal_to_int(d.m_axis_tlast, "m_axis_tlast"))
            if held is not None:  # AXI rule: stalled beat must stay valid and unchanged
                assert valid, "tvalid dropped before the stalled beat was accepted"
                assert cur == held, f"payload changed during backpressure\nheld   ={held}\ncurrent={cur}"
            stall = valid and not ready
            held = cur if stall else None
            if stall:
                s.output_stalls += 1
                s.saw_output_backpressure = True
            if valid and ready:
                await RisingEdge(self.clock)  # transfer happens on this edge
                assert s.expected, f"output beat but scoreboard is empty\nactual={cur}"
                exp = s.expected.popleft()
                assert cur == exp, f"output mismatch\nexpected={exp}\nactual  ={cur}\nleft={len(s.expected)}"
                s.output_beats += 1
                s.output_packets += cur.last
            s.saw_empty |= bool(signal_to_int(d.rempty, "rempty"))
            s.saw_almost_empty |= bool(signal_to_int(d.m_axis_almost_empty, "m_axis_almost_empty"))


async def flag_monitor(dut, state):
    while True:
        await RisingEdge(dut.s_axis_aclk)
        await ReadOnly()
        if signal_to_int(dut.s_axis_aresetn, "s_axis_aresetn"):
            assert int(dut.s_axis_tready.value) == (not int(dut.wfull.value)), "tready must equal !wfull"
            state.saw_full |= bool(int(dut.wfull.value))
            state.saw_almost_full |= bool(int(dut.s_axis_almost_full.value))


async def gray_check(clock, ptr, name):
    # gray crossing is safe iif the pointer changes by at most 1 bit per clk
    prev = signal_to_int(ptr, name)
    while True:
        await RisingEdge(clock)
        cur = signal_to_int(ptr, name)
        assert bin(prev ^ cur).count("1") <= 1, f"{name} jumped {prev:#x} -> {cur:#x}, not gray"
        prev = cur


async def reset_dut(dut):
    for sig in (dut.s_axis_aresetn, dut.m_axis_aresetn, dut.s_axis_tvalid, dut.m_axis_tready):
        sig.value = 0
    await ClockCycles(dut.s_axis_aclk, 8)
    await ClockCycles(dut.m_axis_aclk, 8)
    await FallingEdge(dut.s_axis_aclk)
    dut.s_axis_aresetn.value = 1  # release write side first, read side a few cycles later
    await ClockCycles(dut.m_axis_aclk, 3, rising=False)
    dut.m_axis_aresetn.value = 1
    await ClockCycles(dut.s_axis_aclk, 8)
    await ClockCycles(dut.m_axis_aclk, 8)
    assert int(dut.wfull.value) == 0, "wfull must be low after reset"
    assert int(dut.rempty.value) == 1, "rempty must be high after reset"


async def drain(dut, state, sink, timeout_us=5000):
    sink.mode = "always"

    async def wait():
        while True:
            await RisingEdge(dut.m_axis_aclk)
            if not state.expected and not signal_to_int(dut.m_axis_tvalid, "m_axis_tvalid") \
                    and signal_to_int(dut.rempty, "rempty"):
                await ClockCycles(dut.m_axis_aclk, 5)
                return

    await with_timeout(wait(), timeout_us, "us")


async def run_regression(dut, source, sink, state, rng):
    dut._log.info("phase 1: single-beat packets")
    sink.mode = "always"
    for p in range(50):
        await source.send_packet(p, 1, max_gap=2)
    await drain(dut, state, sink)

    dut._log.info("phase 2: random packets + backpressure")
    sink.mode = "random"
    for p in range(50, 50 + int(os.getenv("RANDOM_PACKETS", "500"))):
        await source.send_packet(p, rng.randint(1, 32), max_gap=rng.randint(0, 5))
    await drain(dut, state, sink)

    dut._log.info("phase 3: fill the fifo, then release slowly")
    sink.mode = "off"
    writer = cocotb.start_soon(source.send_packet(0xF0, 64))
    for _ in range(200):
        await RisingEdge(dut.s_axis_aclk)
        if int(dut.wfull.value):
            break
    else:
        raise AssertionError("fifo never asserted wfull")
    sink.mode = "sparse"
    await with_timeout(writer, 2000, "us")
    await drain(dut, state, sink)

    dut._log.info("phase 4: pointer wraparound with bursty backpressure")
    sink.mode = "bursty"
    for p in range(700, 800):
        await source.send_packet(p, 16, max_gap=rng.randint(0, 2))
    await drain(dut, state, sink)


@cocotb.test()
async def test_axis_async_fifo(dut):
    seed = int(os.getenv("RANDOM_SEED", "12345"), 0)
    rng = random.Random(seed)
    state = State()
    source, sink = AxisSource(dut, state, rng), AxisSink(dut, state, rng)
    source.drive()

    w_ns = int(os.getenv("W_NS", rng.randint(5, 17)))
    r_ns = int(os.getenv("R_NS", rng.randint(5, 17)))
    if w_ns == r_ns:
        r_ns += 1  # same period would make the domains synchronous
    cocotb.log.info("RANDOM_SEED=%d write=%dns read=%dns", seed, w_ns, r_ns)
    cocotb.start_soon(Clock(dut.s_axis_aclk, w_ns, unit="ns").start())
    cocotb.start_soon(Clock(dut.m_axis_aclk, r_ns, unit="ns").start())

    await reset_dut(dut)

    tasks = [cocotb.start_soon(sink.ready_driver()), cocotb.start_soon(sink.monitor()),
             cocotb.start_soon(flag_monitor(dut, state)),
             cocotb.start_soon(gray_check(dut.s_axis_aclk, dut.fifo_core.wptr, "fifo_core.wptr")),
             cocotb.start_soon(gray_check(dut.m_axis_aclk, dut.fifo_core.rptr, "fifo_core.rptr"))]

    await with_timeout(run_regression(dut, source, sink, state, rng), 20, "ms")

    assert not state.expected, f"scoreboard not empty: {len(state.expected)} beats left"
    assert state.input_beats == state.output_beats, f"beats in={state.input_beats} out={state.output_beats}"
    assert state.input_packets == state.output_packets, f"packets in={state.input_packets} out={state.output_packets}"
    for k in COVER:
        assert getattr(state, k), f"coverage failure: {k} never happened"
    for k in COUNTS:
        cocotb.log.info("PASS: %s = %d", k, getattr(state, k))

    sink.running = False
    for t in tasks:
        t.cancel()