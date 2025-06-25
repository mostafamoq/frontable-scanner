#!/usr/bin/env python3
import json
import sys
import os

def get_cidrs(asns_data, target_asn=None):
    cidrs = []
    if target_asn:
        found_asn = False
        for asn_key, data in asns_data.items():
            if data.get('id') == target_asn:
                for cidr in data['netblocks'].keys():
                    cidrs.append(cidr)
                found_asn = True
                break # Found the ASN, no need to check further
        if not found_asn:
            print(f"Warning: ASN {target_asn} not found in ASNs.json.", file=sys.stderr)
    else:
        for asn_key, asn_data in asns_data.items():
            for cidr in asn_data['netblocks'].keys():
                cidrs.append(cidr)
    return cidrs

def list_asns(asns_data):
    """List all ASN names in the format 'AS<number> <organization>'"""
    asn_names = []
    for asn_key, data in asns_data.items():
        asn_id = data.get('id', 'Unknown')
        org_name = data.get('name', 'Unknown Organization')
        asn_names.append(f"{asn_id} {org_name}")
    return sorted(asn_names)

if __name__ == '__main__':
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, 'ASNs.json')
    
    with open(json_path, 'r') as file:
        asns = json.load(file)

    # Check if we should list ASN names or extract CIDRs
    if len(sys.argv) == 1:
        # No arguments: list ASN names
        asn_names = list_asns(asns)
        for asn_name in asn_names:
            print(asn_name)
    elif sys.argv[1] == "--cidrs":
        # --cidrs flag: extract all CIDRs
        extracted_cidrs = get_cidrs(asns)
        for cidr in extracted_cidrs:
            print(cidr)
    else:
        # ASN argument: extract CIDRs for specific ASN
        target_asn = sys.argv[1]
        extracted_cidrs = get_cidrs(asns, target_asn)
        for cidr in extracted_cidrs:
            print(cidr)