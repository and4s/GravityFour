"""Generate a reproducible, legal 125-ply draw for the rules regression suite."""
import json
import random
from pathlib import Path
import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp

N = 5
lines = []
for dx in range(-1, 2):
    for dy in range(-1, 2):
        for dz in range(-1, 2):
            if dx < 0 or (dx == 0 and dy < 0) or (dx == dy == 0 and dz <= 0):
                continue
            for x in range(N):
                for y in range(N):
                    for z in range(N):
                        if not all(0 <= a < N for a in (x + 3*dx, y + 3*dy, z + 3*dz)):
                            continue
                        lines.append([x + k*dx + N*(z + k*dz + N*(y + k*dy)) for k in range(4)])
assert len(lines) == 302
matrix = np.zeros((len(lines)+1, 125))
for i, line in enumerate(lines):
    matrix[i, line] = 1
matrix[-1, :] = 1
lower = np.ones(len(lines)+1)
upper = np.full(len(lines)+1, 3.)
lower[-1] = upper[-1] = 63
rng = random.Random(403)
for attempt in range(20):
    result = milp(np.array([rng.random() for _ in range(125)]), integrality=np.ones(125),
                  bounds=Bounds(0, 1), constraints=LinearConstraint(matrix, lower, upper),
                  options={'time_limit': 15, 'mip_rel_gap': 1})
    if result.x is None:
        continue
    cells = np.rint(result.x).astype(int) + 1
    # 63 ones become player 2: invert so player 1 has the first/last move.
    cells = 3 - cells
    assert sum(cells == 1) == 63
    heights = [0]*25
    failed = set()
    def route(ply):
        if ply == 125:
            return []
        key = tuple(heights)
        if key in failed:
            return None
        side = 1 + ply % 2
        options = [c for c in range(25) if heights[c] < 5 and cells[c + 25*heights[c]] == side]
        rng.shuffle(options)
        options.sort(key=lambda c: heights[c])
        for c in options:
            heights[c] += 1
            suffix = route(ply + 1)
            if suffix is not None:
                return [[c % 5, c // 5]] + suffix
            heights[c] -= 1
        failed.add(key)
        return None
    moves = route(0)
    if moves is not None:
        target = Path(__file__).resolve().parent.parent / 'tests/draw_fixture.json'
        target.write_text(json.dumps(moves), encoding='utf-8')
        print(f'Generated legal draw: {len(moves)} plies, {len(lines)} non-monochromatic segments')
        break
else:
    raise RuntimeError('No legal draw route found')
