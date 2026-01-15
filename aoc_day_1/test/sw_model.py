#!/usr/bin/env python3

cur_pos = 50
zero_count = 0

with open('puzzle_input.txt', 'r') as f:
    for i, line in enumerate(f):
        direction, distance = line[0], int(line[1:])
        distance = distance if distance <= 99 else distance % 100

        if direction == 'L':
            cur_pos = (cur_pos + 100 - distance) if cur_pos < distance else (cur_pos - distance)
        else:
            cur_pos = (cur_pos + distance) % 100

        if cur_pos == 0:
            zero_count += 1

        print(f"Move {i}: {direction}{int(line[1:])} -> pos: {cur_pos}, zeros: {zero_count}")

print(f"\nFinal: pos={cur_pos}, zero_crossings={zero_count}")