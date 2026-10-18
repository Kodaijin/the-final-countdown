#!/usr/bin/env python3
"""Rebuilds site/airports.json, the IATA code -> [lat, lon, city] table the
flight tracker uses when COUNTDOWN_ROUTE sets the route by hand.

Source: OurAirports (public domain), https://ourairports.com/data/
Kept: every airport with an IATA code and scheduled passenger service, plus
large airports without it. ~4,000 entries, ~140 KB, fetched by the page only
when a manual route is configured.

    python3 tools/build-airports.py            # downloads the CSV itself
    python3 tools/build-airports.py airports.csv
"""
import csv
import io
import json
import os
import sys
import urllib.request

SRC = "https://davidmegginson.github.io/ourairports-data/airports.csv"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "site", "airports.json")


def main():
    if len(sys.argv) > 1:
        text = open(sys.argv[1], encoding="utf-8").read()
    else:
        with urllib.request.urlopen(SRC, timeout=60) as r:
            text = r.read().decode("utf-8")

    table = {}
    for row in csv.DictReader(io.StringIO(text)):
        code = row["iata_code"].strip().upper()
        if len(code) != 3 or not code.isalpha():
            continue
        scheduled = row["scheduled_service"] == "yes"
        if not (row["type"] == "large_airport" or
                (scheduled and row["type"] in ("medium_airport", "small_airport"))):
            continue
        # A code reused by a closed or minor field must not displace the real one.
        rank = (row["type"] == "large_airport", scheduled)
        if code in table and table[code][1] >= rank:
            continue
        city = row["municipality"].split(",")[0].strip() or row["name"]
        table[code] = ([round(float(row["latitude_deg"]), 3),
                        round(float(row["longitude_deg"]), 3), city], rank)

    data = {k: v[0] for k, v in sorted(table.items())}
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print("wrote %d airports to %s" % (len(data), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
