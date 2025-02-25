#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2024 Simone Caronni <negativo17@gmail.com>
# Licensed under the GNU General Public License Version or later

import argparse
import json

# Argument parsing
parser = argparse.ArgumentParser(description="Parse a supported-gpus.json file and print an RPM supplement list.")
parser.add_argument("--flavor", help="Specify kernel flavor", required=True)
parser.add_argument("INPUT_JSON", help="The JSON file to be parsed", type=argparse.FileType('r'))

group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--closed", help="Select GPUs supported only by the closed modules", action="store_true")
group.add_argument("--open", help="Select GPUs supported by the open module", action="store_true")

args = parser.parse_args()

# Load JSON
gpus_raw = json.load(args.INPUT_JSON)

# Collect valid GPU IDs
devids = set()  # Use a set to prevent duplicates

for product in gpus_raw["chips"]:
    gpu_id = product["devid"].lower().replace("0x", "")  # Normalize to lowercase hex
    
    if args.closed:
        # Include GPUs **not** having "kernelopen" in "features"
        if "kernelopen" in product.get("features", []):
            continue
    elif args.open:
        # Include GPUs **only** having "kernelopen" in "features"
        if "kernelopen" not in product.get("features", []):
            continue

    devids.add(gpu_id)

# Generate and print the output
for gpu in sorted(devids):  # Sort to ensure consistent output order
    print(f"Supplements: modalias(kernel-{args.flavor}:pci:v000010DEd0000{gpu}sv*sd*bc03sc0[02]i00*)")
