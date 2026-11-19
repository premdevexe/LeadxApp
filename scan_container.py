#!/usr/bin/env python3
"""Find every `Container(` whose top-level arguments include both `color:` and
`decoration:`.

String- and comment-aware. Only identifiers at depth 1 of the `Container(...)`
call are collected, so a `color:` buried inside a `BoxDecoration(...)` is never
miscounted.

Run from anywhere:  python scan_container.py
"""
import os
import sys

LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib")


def skip_interpolation(text, i):
    """i points just after `${`. Return index just past the matching `}`."""
    n = len(text)
    depth = 1
    while i < n:
        c = text[i]
        if c in ('"', "'"):
            q = c
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == q or text[i] == "\n":
                    i += 1
                    break
                i += 1
            continue
        if c == "$" and i + 1 < n and text[i + 1] == "{":
            depth += 1
            i += 2
            continue
        if c in "([{":
            depth += 1
            i += 1
            continue
        if c in ")]}":
            depth -= 1
            if depth == 0:
                return i + 1
            i += 1
            continue
        i += 1
    return n


def top_level_args(text, open_idx):
    """Top-level (depth-1) named-arg names of the call whose '(' is at open_idx."""
    n = len(text)
    i = open_idx + 1
    depth = 1
    in_str = False
    str_q = None
    args = []
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == "$" and i + 1 < n and text[i + 1] == "{":
                i = skip_interpolation(text, i + 2)
                continue
            if c == str_q or c == "\n":
                in_str = False
                i += 1
                continue
            i += 1
            continue
        # code context
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        if c in ('"', "'"):
            in_str = True
            str_q = c
            i += 1
            continue
        if c in "([{":
            depth += 1
            i += 1
            continue
        if c in ")]}":
            depth -= 1
            if depth == 0:
                return args
            i += 1
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            name = text[i:j]
            if depth == 1:
                k = j
                while k < n and text[k] in " \t\r\n":
                    k += 1
                if k < n and text[k] == ":":
                    args.append(name)
            i = j
            continue
        i += 1
    return args


def find_container_calls(text):
    """Yield (line, [args]) for every `Container(` call that has BOTH
    `color:` and `decoration:` as top-level arguments."""
    n = len(text)
    i = 0
    in_str = False
    str_q = None
    in_comment = False
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == "$" and i + 1 < n and text[i + 1] == "{":
                i = skip_interpolation(text, i + 2)
                continue
            if c == str_q or c == "\n":
                in_str = False
                str_q = None
            i += 1
            continue
        if in_comment:
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                in_comment = False
                i += 2
                continue
            i += 1
            continue
        # code
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            in_comment = True
            i += 2
            continue
        if c in ('"', "'"):
            in_str = True
            str_q = c
            i += 1
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            word = text[i:j]
            if word == "Container":
                k = j
                while k < n and text[k] in " \t\r\n":
                    k += 1
                if k < n and text[k] == "(":
                    args = top_level_args(text, k)
                    if "color" in args and "decoration" in args:
                        line = text.count("\n", 0, k) + 1
                        yield (line, args)
            i = j
            continue
        i += 1


def main():
    found = 0
    scanned_files = 0
    total_container_calls = 0
    for root, _, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(root, fn)
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
            scanned_files += 1
            hits = list(find_container_calls(text))
            # also count total Container( occurrences as a sanity signal
            total_container_calls += text.count("Container(")
            for line, args in hits:
                rel = os.path.relpath(path, os.path.dirname(LIB))
                print(f"{rel}:{line}  -> {sorted(args)}")
                found += 1
    print("---")
    print(f"files scanned: {scanned_files}")
    print(f"total 'Container(' tokens seen: {total_container_calls}")
    print(f"total Container(color + decoration) collisions: {found}")
    sys.exit(0 if found == 0 else 1)


if __name__ == "__main__":
    main()
