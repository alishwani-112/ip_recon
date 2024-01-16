#!/bin/bash

# Default values
ips_folder="$PWD/ip_folder"
maindomain=""
host=""
scan_type="all"

# Help function
display_help() {
    echo "Usage: $0 -d <maindomain> -s <hostfile> [-o <outputfolder>] [-t <scan_type>] [-h]"
    echo "Options:"
    echo "  -d  Specify the main domain."
    echo "  -s  Specify the host file."
    echo "  -o  Specify the output directory (optional, default: $ips_folder)."
    echo "  -t  Specify the scan type: 'all' (default), 'subs', or 'ip'."
    echo "  -h  Display this help message."
    exit 1
}

# Function to create output directory if it doesn't exist
create_output_directory() {
    local directory="$1"
    if [ -d "$directory" ]; then
        echo "Directory '$directory' already exists."
    else
        echo "Creating directory '$directory'."
        mkdir "$directory"
    fi
}

# Function to validate inputs
validate_inputs() {
    if [ -z "$maindomain" ] || [ -z "$host" ]; then
        echo "Error: Main domain and host file are required."
        display_help
    fi
}

# Function to perform open port scanning and IP resolution
perform_ip_recon() {
    local domain="$1"
    local host_file="$2"

    case "$scan_type" in
        all)
            echo "Running all types of scans for $domain"
            naabu -l "$host_file" -tp full -Pn -v -sD -rate 3000 -o "$ips_folder/openport_host"
            awk '{print $1}' "$host_file" | xargs -I {} host {} | grep "has address" | awk -F 'address' '{print$2}' > "$ips_folder/ip"
            sort -u "$ips_folder/ip" > "$ips_folder/ip_sorted"
            grep -vE 'cloudflare|fastly|Leaseweb|AkamaiGHost|BigIP|awselb|snow_adc|Azure|AWS|Akamai|StackPath|KeyCDN|Microsoft-IIS' "$ips_folder/ip_sorted" > "$ips_folder/ip_sorted_nocdn"
            naabu -l "$ips_folder/ip_sorted_nocdn" -v -tp full -Pn -sD -rate 3000 -o "$ips_folder/openport_ip_all"
            ;;
        subs)
            echo "Running open port scanning for $domain"
            naabu -l "$host_file" -tp full -Pn -sD -v -rate 3000 -o "$ips_folder/openport_host"
            ;;
        ip)
            echo "Resolving IPs for $domain"
            awk '{print $1}' "$host_file" | xargs -I {} host {} | grep "has address" | awk -F 'address' '{print$2}' > "$ips_folder/ip"
            grep -vE 'cloudflare|fastly|Leaseweb|AkamaiGHost|BigIP|awselb|snow_adc|Azure|AWS|Akamai|StackPath|KeyCDN|Microsoft-IIS' "$ips_folder/ip" > "$ips_folder/ip_sorted"
            naabu -l "$ips_folder/ip_sorted" -tp full -v -Pn -sD -rate 3000 -o "$ips_folder/openport_ip"
            ;;
        *)
            echo "Error: Invalid scan type specified. Use 'all', 'subs', or 'ip'."
            exit 1
            ;;
    esac
}

# Function to create a placeholder file
create_placeholder_file() {
    touch "$ips_folder/f0ip"
}

# Main execution
while getopts "d:s:o:t:h" flag; do
    case "${flag}" in
        d) maindomain="${OPTARG}" ;;
        s) host="${OPTARG}" ;;
        o) ips_folder="${OPTARG}" ;;
        t) scan_type="${OPTARG}" ;;
        h) display_help ;;
        *) display_help ;;
    esac
done

validate_inputs
create_output_directory "$ips_folder"
perform_ip_recon "$maindomain" "$host"

create_placeholder_file

echo "Script completed. Results saved to $ips_folder."
