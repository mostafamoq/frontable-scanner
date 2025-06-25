# Domain Fronting IP Scanner - Find IPs for Stealthy Connections

This tool helps you find special internet addresses (IPs) that can be used for **domain fronting**. Think of it like sending your internet traffic disguised as regular traffic to a popular website. This can be very useful for getting around internet restrictions or censorship, especially when setting up tools like Xray.

## ✨ What This Tool Does

This scanner automates a complex process to: 

*   **Find Hidden IPs**: It scans large parts of the internet to find servers that might allow domain fronting.
*   **Test for Stealth**: It performs special checks to ensure these IPs can truly hide your traffic by looking like legitimate connections to a popular website (your "decoy").
*   **Easy to Use**: A simple setup script gets you started, and the main tool guides you step-by-step through the scanning process.
*   **Works Everywhere**: Designed for both Apple Mac (macOS) and various Linux computers.
*   **Organized Results**: All your findings and logs are neatly saved in separate folders.

## 🔧 What You Need (Requirements)

This tool needs a few other programs to work. Don't worry, our easy `install.sh` script will try to set most of them up for you automatically!

Here are the main tools it will check for:

*   **`whois`**: Helps find network information.
*   **`jq`**: A tool for reading and understanding special data files.
*   **`masscan`**: A super-fast internet scanner. (Heads up: It needs special admin permissions (`sudo`) to run!)
*   **`timeout` / `gtimeout`**: Makes sure commands don't run forever.
*   **`openssl`**: Used for secure internet communication tests.
*   **`curl`**: A common tool for fetching web pages and testing connections.
*   **Basic System Tools**: Other everyday commands like `grep`, `sort`, `wc`, etc., which are usually already on your computer.
*   **Python 3**: For a small part of the script that handles network data.

## 🚀 Getting Started (Installation & Setup)

Follow these simple steps to get your Domain Fronting IP Scanner ready:

1.  **Get the Tool (Clone the Repository)**:
    Open your Terminal app (on Mac) or command line (on Linux) and type:
    ```bash
    git clone <repository_url> # Replace <repository_url> with the actual link to this project
    cd <repository_name>     # Go into the project folder
    ```

2.  **Add Your ASN List (Important File)**:
    This tool needs a list of internet network numbers (ASNs) to scan. You'll need a file named `ASNs.json` that contains this data. Place this file inside the `py/` folder of this project.
    
    *What `ASNs.json` looks like (example):*
    ```json
    {
        "AS16509 Amazon.com, Inc.": { // This is one entry, starting with "AS" and the company name
            "id": "AS16509",         // The actual ASN number
            "name": "Amazon.com, Inc.",
            "netblocks": {          // List of internet address ranges for this ASN
                "3.0.0.0/10": "Amazon Technologies Inc.",
                "3.128.0.0/10": "Amazon Technologies Inc."
                // ... more network ranges
            }
        }
        // ... many more ASNs listed here
    }
    ```

3.  **Make the Installer Ready (Executable)**:
    ```bash
    chmod +x install.sh
    ```

4.  **Tell the Installer Where to Download From (Set GitHub URL)**:
    You need to tell the `install.sh` script where to download the other parts of the tool from. Open the `install.sh` file in a text editor (like `nano install.sh` or `code install.sh`) and find this line:
    `GITHUB_RAW_BASE_URL="YOUR_GITHUB_REPO_RAW_URL"`
    
    Replace `YOUR_GITHUB_REPO_RAW_URL` with the actual link to the "raw" version of your GitHub repository. This is usually something like `https://raw.githubusercontent.com/your-username/your-repo-name/main`.
    
    *Example: If your GitHub username is `myuser` and your repository is `my-fronting-tool`, it would be `https://raw.githubusercontent.com/myuser/my-fronting-tool/main`*

5.  **Run the Main Installer!** (Choose one option):

    *   **Option A: Simple Download & Run (Recommended for first-time setup)**
        If you've already cloned the repository and are in its directory, simply run:
        ```bash
        ./install.sh
        ```
        This script will do all the heavy lifting:
        *   It figures out if you're on a Mac or Linux.
        *   It checks for and installs all the extra programs you need.
        *   It creates a special folder (`~/frontable-scanner`) on your computer for the tool.
        *   It downloads all the necessary files (like the main scanner scripts and your `ASNs.json`).
        *   It makes sure all the scripts can be run.
        *   **Important**: It will ask you if you want to set up a handy command called `frontable`. We highly recommend saying **yes** (`y`) to this! It makes running the scanner much easier later.

    *   **Option B: One-Line Install (For quick setup from anywhere)**
        You can also download and run the installer directly from GitHub using a single command. Open your Terminal and type:
        ```bash
        bash <(curl -Ls https://raw.githubusercontent.com/mostafamoq/frontable-scanner/main/install.sh)
        ```
        This command will fetch the `install.sh` script and execute it immediately. It performs the same steps as Option A.

    *Note: If `masscan` (the fast scanner) gives you trouble during installation, you might need to install it manually. It sometimes needs special steps depending on your Linux version.* 

## 💡 How to Use the Scanner

Once the installation is done, using the scanner is interactive and straightforward!

**First, open a brand new Terminal window.** This makes sure your computer knows about the new `frontable` command (if you chose to set it up).

Then, simply type:

```bash
frontable [--log=debug|info|quiet]
```

*   **`--log=debug`**: Shows you a lot of detailed messages – great for troubleshooting if something goes wrong.
*   **`--log=info` (Default)**: Shows you the main progress messages.
*   **`--log=quiet`**: Keeps the output minimal, only showing very important messages.

*(If you didn't set up the `frontable` command, you'll need to go to the `~/frontable-scanner` folder and run `./find_frontable.sh` (for Mac) or `./find_frontable_linux.sh` (for Linux) instead.)*

**Interactive Questions (The Script Will Ask You These!):**

When you run the `frontable` command, it will ask you a few questions:

1.  **"Enter the full decoy URL..."**: This is the important website address you want your traffic to look like it's going to. Make sure to include `https://` and any specific path (e.g., `https://test.something.something/ws?xxx`).

2.  **"Enter a name for the Internet Provider..."**: Give a simple name (like "Cloudflare" or "MyHomeISP"). This helps organize the results into a clear folder (e.g., `output/Cloudflare/`).

3.  **"Select an ASN..."**: The script will show you a numbered list of ASNs (from your `ASNs.json` file). You can type the number next to an ASN to scan only that one, or type `all` to scan every ASN in your list.

After you answer these questions, the scanner will get to work!

## 📊 Understanding What You Find (Results)

All your scan results will be saved in a new folder called `output/` inside your `~/frontable-scanner` directory. Inside `output/`, you'll find subfolders named after the "Internet Provider" you entered.

*   **Found IPs File (`frontable-<ASN>.txt` or `frontable-all_ASNs-<date>.txt`)**: This plain text file will contain a list of IP addresses that successfully passed all the tests. These are the IPs that are likely good candidates for domain fronting with your chosen decoy!
*   **Log File (`frontable-<ASN>.log` or `frontable-all_ASNs-<date>.log`)**: This file keeps a detailed record of everything the script did. It's very useful if you need to figure out why an IP didn't work (especially with `--log=debug`).

**What the Messages Mean in the Log File:**

*   `✔︎ <IP_ADDRESS>`: Great! This IP successfully passed all the domain fronting checks.
*   `✘ <IP_ADDRESS> (TLS handshake failed)`: The IP responded on port 443, but the secure connection (TLS) with your decoy website didn't work as expected.
*   `✘ <IP_ADDRESS> (TLS OK, but curl test failed)`: The secure connection worked, but the server didn't give the expected "Bad Request" message. This often means the server isn't configured for domain fronting in the way your decoy URL expects, or the specific path in your decoy URL isn't right for that server.

## 🧪 Using Found IPs in Xray (Example Config)

Once you have a list of working IPs, you can plug them into your Xray configuration. Here's a simplified example for a VLESS outbound connection:

```json
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "YOUR_FRONTABLE_IP", // IMPORTANT: Replace with an IP you found in the results file!
            "port": 443,
            "users": [
              {
                "encryption": "none",
                "id": "YOUR_UUID_HERE" // Replace with your unique Xray ID (UUID)
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "h3",
            "h2",
            "http/1.1"
          ],
          "fingerprint": "randomized",
          "serverName": "YOUR_DECOY_HOSTNAME" // This is the main part of your decoy URL (e.g., https://test.something.something)
        },
        "wsSettings": {
          "host": "YOUR_DECOY_HOSTNAME", // Same as above
          "path": "YOUR_DECOY_PATH" // This is the path from your decoy URL (e.g., /ws?ed=462892)
        }
      },
      "tag": "proxy"
    }
  ]
}
```

**Remember to replace all the `YOUR_...` placeholders with your actual values!**

## 🐛 Troubleshooting & Common Issues

If something isn't working right, here are some common problems and how to fix them:

*   **`masscan needs root →`**: The `masscan` tool needs special permissions. Just type your computer's password when it asks you.
*   **`Error: <tool_name> not found. Please install it manually.`**: The `install.sh` script tried to install a program but couldn't, or your Linux version isn't supported by its auto-install feature. You'll need to install that program yourself using your system's package manager (e.g., `sudo apt install <tool_name>` on Ubuntu).
*   **`ERROR: GITHUB_RAW_BASE_URL is a placeholder.`**: You forgot to edit `install.sh`! Open it and replace `YOUR_GITHUB_REPO_RAW_URL` with the correct link to your GitHub repository's raw files.
*   **`No ASNs found in py/ASNs.json.`**: The `ASNs.json` file is either missing, empty, or has an error in its formatting. Make sure it's in the `py/` folder within `~/frontable-scanner` and looks like the example in the setup guide.
*   **`Warning: ASN ASXXXXXX not found in ASNs.json.`**: The specific ASN number you typed wasn't found in the `ASNs.json` file. Double-check the number or choose `all` to scan everything.
*   **No IPs found in the results file (`frontable-*.txt`)**: This means the scanner couldn't find any IPs that work for domain fronting with your settings. This could be because:
    *   `masscan` didn't find any open port 443 servers.
    *   The secure connection (TLS) tests failed for all discovered IPs.
    *   The final `curl` test didn't get the "Bad Request" message. This test is very specific to how your decoy server is set up. Make sure your `FULL_DECOY_URL` is exactly right.
    *   **What to try**: Pick a different ASN, or scan `all` ASNs. You could also try temporarily removing or simplifying the `curl` check inside the `probe_one` function (in `find_frontable.sh` or `find_frontable_linux.sh`) to see if IPs are being found with just the TLS test.
*   **`ValueError: I/O operation on closed file.` or other Python errors from `py/checker.py`**: Your `ASNs.json` file might be corrupted or have incorrect formatting. Also, ensure Python 3 is correctly installed on your system.

If you're still stuck, please describe your problem in detail and open an issue on the project's GitHub page. We're here to help! 