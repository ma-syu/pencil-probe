#!/bin/bash
# Regenerate patches/phase2-pencil-tcp.patch from the unpatched upstream
# and the desired modifications.
#
# Idempotent: running twice produces the same output.
# Requires: ~/projects/VirtualMacOniPad git repo with commit 9056beb
#           (upstream 1.1.2 before our Pencil changes)

set -euo pipefail

UPSTREAM=~/projects/VirtualMacOniPad
ORIG_COMMIT=9056beb   # upstream 1.1.2, pre-patch
FILE=VirtualMac/vz/host/VirtualMacApp.m
OUT=patches/phase2-pencil-tcp.patch

cd "$(dirname "$0")/.."

orig=$(mktemp)
modified=$(mktemp)
trap 'rm -f "$orig" "$modified"' EXIT

git -C "$UPSTREAM" show "${ORIG_COMMIT}:${FILE}" > "$orig"

REGEN_ORIG="$orig" REGEN_MODIFIED="$modified" python3 << 'PYEOF'
import sys

import os, sys
orig_path = os.environ["REGEN_ORIG"]
modified_path = os.environ["REGEN_MODIFIED"]
with open(orig_path) as f:
    lines = f.readlines()

includes = "#include <sys/socket.h>\n#include <netinet/in.h>\n#include <netinet/tcp.h>\n#include <arpa/inet.h>\n"

tcp_funcs = '''
// --- Pencil TCP relay ---
//
// Sends 13-byte packets to the guest VM relay server.
// Wire format (LE): type(u8) | pressure(f32) | x(f32) | y(f32)
// type: 0=point, 1=proximity_enter, 2=proximity_leave

static int gPencilTcpFd = -1;

static void pencilTcpConnect(void) {
    if (gPencilTcpFd >= 0) return;

    const char *host = getenv("PENCIL_RELAY_HOST");
    if (!host) host = "192.168.1.2";
    const char *portStr = getenv("PENCIL_RELAY_PORT");
    uint16_t port = portStr ? (uint16_t)atoi(portStr) : 9923;

    gPencilTcpFd = socket(AF_INET, SOCK_STREAM, 0);
    if (gPencilTcpFd < 0) return;

    int nd = 1;
    setsockopt(gPencilTcpFd, IPPROTO_TCP, TCP_NODELAY, &nd, sizeof(nd));

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host);

    if (connect(gPencilTcpFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        printf("[Pencil] TCP connect %s:%u failed: %s\\n",
               host, port, strerror(errno));
        close(gPencilTcpFd);
        gPencilTcpFd = -1;
        return;
    }
    printf("[Pencil] TCP connected to %s:%u\\n", host, port);
}

static void pencilTcpWriteLE32(uint8_t *buf, float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    buf[0] = (uint8_t)(bits);
    buf[1] = (uint8_t)(bits >> 8);
    buf[2] = (uint8_t)(bits >> 16);
    buf[3] = (uint8_t)(bits >> 24);
}

static void pencilTcpSend(uint8_t type, float pressure,
                           float nx, float ny) {
    if (gPencilTcpFd < 0) pencilTcpConnect();
    if (gPencilTcpFd < 0) return;

    uint8_t buf[13];
    buf[0] = type;
    pencilTcpWriteLE32(buf + 1, pressure);
    pencilTcpWriteLE32(buf + 5, nx);
    pencilTcpWriteLE32(buf + 9, ny);

    ssize_t n = write(gPencilTcpFd, buf, 13);
    if (n <= 0) {
        printf("[Pencil] TCP write failed, disconnecting\\n");
        close(gPencilTcpFd);
        gPencilTcpFd = -1;
    }
}
'''

pencil_began = '''    for (UITouch *t in touches) {
        if (t.type == UITouchTypeStylus) {
            CGPoint p = [t locationInView:self];
            CGRect b = self.bounds;
            float pressure = (t.maximumPossibleForce > 0)
                ? (float)(t.force / t.maximumPossibleForce) : 0;
            float nx = (b.size.width > 0) ? (float)(p.x / b.size.width) : 0;
            float ny = (b.size.height > 0) ? (float)(p.y / b.size.height) : 0;
            pencilTcpSend(1, pressure, nx, ny);
            return;
        }
    }
'''

pencil_moved = '''    for (UITouch *t in touches) {
        if (t.type == UITouchTypeStylus) {
            CGPoint p = [t locationInView:self];
            CGRect b = self.bounds;
            float pressure = (t.maximumPossibleForce > 0)
                ? (float)(t.force / t.maximumPossibleForce) : 0;
            float nx = (b.size.width > 0) ? (float)(p.x / b.size.width) : 0;
            float ny = (b.size.height > 0) ? (float)(p.y / b.size.height) : 0;
            pencilTcpSend(0, pressure, nx, ny);
            return;
        }
    }
'''

pencil_ended = '''    for (UITouch *t in touches) {
        if (t.type == UITouchTypeStylus) {
            CGPoint p = [t locationInView:self];
            CGRect b = self.bounds;
            float nx = (b.size.width > 0) ? (float)(p.x / b.size.width) : 0;
            float ny = (b.size.height > 0) ? (float)(p.y / b.size.height) : 0;
            pencilTcpSend(2, 0, nx, ny);
            return;
        }
    }
'''

# Verify anchor lines (1-indexed)
assert '#include <pthread.h>' in lines[20]
assert '}' == lines[1699].strip()
assert '}' == lines[1708].strip()
assert '}' == lines[1757].strip()
assert '{' == lines[1781].strip()

# Insert from bottom to top
lines.insert(1782, pencil_ended)
lines.insert(1758, pencil_moved)
lines.insert(1709, pencil_began)
lines.insert(1700, tcp_funcs)
lines.insert(21, includes)

with open(modified_path, 'w') as f:
    f.writelines(lines)
PYEOF

diff -u "$orig" "$modified" \
  | sed "s|$orig|a/${FILE}|;s|$modified|b/${FILE}|" \
  > "$OUT" || [ $? -eq 1 ]

# Verify round-trip
verify=$(mktemp)
trap 'rm -f "$orig" "$modified" "$verify"' EXIT
cp "$orig" "$verify"
patch -s "$verify" "$OUT"
diff -q "$verify" "$modified" > /dev/null

echo "Generated $OUT ($(wc -l < "$OUT") lines)"
