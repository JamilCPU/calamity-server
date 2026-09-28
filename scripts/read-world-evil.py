"""Reads a Terraria .wld header and reports whether the world is Crimson or Corruption.

There is no server command for this, and the count of world-flag booleans between
gameMode and creationTime varies by format version (drunkWorld, getGoodWorld,
tenthAnniversary, dontStarve, notTheBees, remix, noTraps, zenith...). Rather than
trust a version table, this tries every plausible count and keeps only the ones
whose later fields all land in sane ranges (spawn point inside the world, surface
above rock layer, dungeon inside the world, moon phase 0-7). If exactly one count
validates, its crimson flag is trustworthy.
"""
import struct
import sys


class Reader:
    def __init__(self, data, pos=0):
        self.d = data
        self.p = pos

    def i16(self):
        v = struct.unpack_from('<h', self.d, self.p)[0]; self.p += 2; return v

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]; self.p += 4; return v

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]; self.p += 4; return v

    def u64(self):
        v = struct.unpack_from('<Q', self.d, self.p)[0]; self.p += 8; return v

    def f64(self):
        v = struct.unpack_from('<d', self.d, self.p)[0]; self.p += 8; return v

    def byte(self):
        v = self.d[self.p]; self.p += 1; return v

    def boolean(self):
        return self.byte() != 0

    def string(self):
        n = 0; shift = 0
        while True:
            b = self.byte()
            n |= (b & 0x7F) << shift
            if not (b & 0x80):
                break
            shift += 7
        s = self.d[self.p:self.p + n].decode('utf-8', 'replace'); self.p += n
        return s


def parse(path):
    data = open(path, 'rb').read()
    r = Reader(data)
    version = r.i32()
    magic = data[r.p:r.p + 7].decode('ascii', 'replace'); r.p += 7
    r.byte()            # file type
    r.u32()             # revision
    r.u64()             # favorite
    npointers = r.i16()
    pointers = [r.i32() for _ in range(npointers)]
    print(f"version={version} magic={magic!r} pointers={npointers}")

    h = Reader(data, pointers[0])
    name = h.string()
    seed = h.string()
    h.u64()                                  # worldGenVersion
    h.p += 16                                # guid
    world_id = h.i32()
    left, right, top, bottom = h.i32(), h.i32(), h.i32(), h.i32()
    max_y = h.i32()
    max_x = h.i32()
    print(f"name={name!r} seed={seed!r} id={world_id} bounds=({left},{right},{top},{bottom}) size={max_x}x{max_y}")

    anchor_pos = h.p
    results = []
    for extra_bools in range(0, 9):
        try:
            g = Reader(data, anchor_pos)
            game_mode = g.i32()
            flags = [g.boolean() for _ in range(extra_bools)]
            g.u64()                          # creationTime
            g.byte()                         # moonType
            for _ in range(3):
                g.i32()                      # treeX
            for _ in range(4):
                g.i32()                      # treeStyle
            for _ in range(3):
                g.i32()                      # caveBackX
            for _ in range(4):
                g.i32()                      # caveBackStyle
            g.i32(); g.i32(); g.i32()        # ice / jungle / hell back style
            spawn_x = g.i32(); spawn_y = g.i32()
            surface = g.f64(); rock = g.f64()
            g.f64()                          # time
            g.boolean()                      # dayTime
            moon_phase = g.i32()
            g.boolean(); g.boolean()         # bloodMoon, eclipse
            dungeon_x = g.i32(); dungeon_y = g.i32()
            crimson = g.boolean()

            # Ranges are deliberately strict: allowing zeros lets a wrong offset
            # validate on an all-zero run of bytes. Spawn sits near the horizontal
            # centre of a fresh world, and the dungeon is never at the very edge.
            ok = (
                0.2 * max_x < spawn_x < 0.8 * max_x and 0 < spawn_y < max_y
                and 0 < surface < max_y and surface < rock < max_y
                and 0 < dungeon_x < max_x and 0 < dungeon_y < max_y
                and 0 <= moon_phase <= 8
                and 0 <= game_mode <= 3
            )
            if ok:
                results.append((extra_bools, game_mode, crimson, spawn_x, spawn_y,
                                surface, rock, dungeon_x, dungeon_y, flags))
        except Exception:
            continue

    if not results:
        print("NO CANDIDATE VALIDATED - cannot trust a reading")
        return 2

    for (nb, gm, crim, sx, sy, surf, rock, dx, dy, flags) in results:
        print(f"  flags={nb} gameMode={gm} spawn=({sx},{sy}) surface={surf:.0f} rock={rock:.0f} "
              f"dungeon=({dx},{dy}) -> {'CRIMSON' if crim else 'CORRUPTION'}")

    verdicts = {r[2] for r in results}
    if len(verdicts) == 1:
        print(f"\nVERDICT: {'CRIMSON' if verdicts.pop() else 'CORRUPTION'} "
              f"({len(results)} candidate layout(s) agree)")
        return 0
    print("\nAMBIGUOUS: candidate layouts disagree")
    return 3


if __name__ == '__main__':
    sys.exit(parse(sys.argv[1]))
