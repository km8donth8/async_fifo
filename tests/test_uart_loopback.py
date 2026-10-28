"""hardware UART loopback test for the Tang Nano 20K.

sends every byte value 0-255 one at a time, waits for the echo that has been
through uart_rx -> async FIFO -> uart_tx, and checks it matches.

cannot stress full/empty behaviour as UART TX is the bottleneck, however test_async_fifo.py does.

"""
import sys
import serial


def main():
    port = sys.argv[1] if len(sys.argv) > 1 else "COM5"
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200

    tx = bytes(range(256))
    rx = bytearray()

    with serial.Serial(port, baud, timeout=1) as s:
        s.reset_input_buffer()
        for b in tx:
            s.write(bytes([b]))
            s.flush()
            rx.extend(s.read(1))  #empty read on timeout shows up as mismatch

    mismatch = next((i for i, (a, b) in enumerate(zip(tx, rx)) if a != b), None)
    if mismatch is None and len(rx) != len(tx):
        mismatch = len(rx)

    print(f"sent {len(tx)}, received {len(rx)}")
    if mismatch is None:
        print("PASS: all 256 bytes echoed correctly")
        return 0
    print(f"FAIL: first mismatch at byte {mismatch}")
    return 1


if __name__ == "__main__":
    sys.exit(main())