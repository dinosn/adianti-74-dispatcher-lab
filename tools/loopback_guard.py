#!/usr/bin/env python3
"""Accept only plain HTTP URLs whose host is an explicit loopback endpoint."""

from __future__ import annotations

import argparse
import ipaddress
import socket
import sys
from urllib import parse


def normalize_loopback_url(value: str) -> str:
    candidate = value.strip().rstrip("/")
    parsed = parse.urlsplit(candidate)
    if parsed.scheme != "http" or not parsed.hostname:
        raise ValueError("URL must be an absolute HTTP loopback URL")
    if parsed.username or parsed.password:
        raise ValueError("URL must not contain credentials or userinfo")
    if parsed.path or parsed.query or parsed.fragment:
        raise ValueError("URL must not contain a path, query, or fragment")
    try:
        port = parsed.port or 80
    except ValueError as exc:
        raise ValueError("URL contains an invalid port") from exc

    if parsed.hostname == "localhost":
        try:
            addresses = {
                item[4][0]
                for item in socket.getaddrinfo(parsed.hostname, port, type=socket.SOCK_STREAM)
            }
        except socket.gaierror as exc:
            raise ValueError("localhost cannot be resolved") from exc
        if not addresses or any(not ipaddress.ip_address(address).is_loopback for address in addresses):
            raise ValueError("localhost must resolve only to loopback")
    else:
        try:
            literal = ipaddress.ip_address(parsed.hostname)
        except ValueError as exc:
            raise ValueError("host must be localhost or a literal loopback address") from exc
        if not literal.is_loopback:
            raise ValueError("host must be a loopback address")

    return parse.urlunsplit(("http", parsed.netloc, "", "", ""))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate one loopback-only HTTP origin")
    parser.add_argument("url")
    args = parser.parse_args()
    try:
        normalize_loopback_url(args.url)
    except ValueError as exc:
        print(f"Refusing non-loopback URL: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
