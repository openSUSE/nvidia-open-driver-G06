#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2024 Simone Caronni <negativo17@gmail.com>
# Licensed under the GNU General Public License Version or later

import argparse
import json

parser = argparse.ArgumentParser(description="Parse a supported-gpus.json file and prints a RPM supplement list.")
parser.add_argument("--flavor", help="Specify kernel flavor", required=True)
parser.add_argument("INPUT_JSON", help="The JSON file to be parsed", type=argparse.FileType('r'))
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--closed", help="Select GPUs supported only by the closed modules", action="store_true")
group.add_argument("--open", help="Select GPUs supported by the open module", action="store_true")
args = parser.parse_args()

gpus_raw = json.load(args.INPUT_JSON)

devids = []

for product in gpus_raw["chips"]:

    if args.closed and "legacybranch" not in product.keys() and "kernelopen" not in product["features"]:
        continue

    if args.open and "kernelopen" in product["features"]:
        continue

    gpu = product["devid"].replace("0x",'')
    if not gpu in devids:
        devids.append(gpu)

for gpu in devids:
    print(f"Supplements modalias(kernel-" + args.flavor + ":pci:v000010DEd0000" + gpu + "sv*sd*bc03sc0[02]i00*)")
