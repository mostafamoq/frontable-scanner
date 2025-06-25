# 🎯 Domain Fronting IP Scanner

> **Find special IPs for domain fronting to bypass internet restrictions and enhance privacy.**

---

## 🚀 **Quick Installation**

**Just run this single command in your terminal:**

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mostafamoq/frontable-scanner/main/install.sh)
```

That's it! The installer will:
- ✅ Detect your OS (macOS/Linux) 
- ✅ Install all dependencies automatically
- ✅ Set up the `frontable` command
- ✅ Download latest scripts and data

---

## 📋 **Requirements**

### **🖥️ System Requirements:**
- **macOS** 10.12+ or **Linux** (Ubuntu 18.04+, CentOS 7+, etc.)
- **Internet connection** for downloading dependencies and scanning
- **sudo access** for masscan (network scanning requires root privileges)

### **🔧 Dependencies (Auto-installed):**
| Tool | Purpose | Installation |
|------|---------|--------------|
| **`masscan`** | High-speed port scanner | `brew install masscan` / `apt install masscan` |
| **`openssl`** | TLS connection testing | Usually pre-installed |
| **`curl`** | HTTP testing and downloads | Usually pre-installed |
| **`python3`** | ASN data processing | `brew install python3` / `apt install python3` |
| **`jq`** | JSON data parsing | `brew install jq` / `apt install jq` |
| **`whois`** | Network information lookup | `brew install whois` / `apt install whois` |
| **`timeout`/`gtimeout`** | Command timeouts | `brew install coreutils` / `apt install coreutils` |

**💡 Note:** The installer handles all dependencies automatically - you don't need to install anything manually!

---

## 💡 **How to Use**

After installation, simply run:

```bash
frontable
```

The tool will interactively ask you:

1. **🎭 Decoy URL**: Your target ws xray vless protocol address (e.g., `https://example.com/ws-set-path`)
2. **🏢 Provider Name**: For organizing results (e.g., "MCI", "MKH", ...)  
3. **🌐 ASN Selection**: Choose from popular providers or search all networks

### **Popular ASNs Available:**
- 🔥 **AS13335** Cloudflare, Inc.
- 🔥 **AS16509** Amazon.com, Inc. 
- 🔥 **AS15169** Google LLC
- 🔥 **AS8075** Microsoft Corporation
- 🔥 **AS54113** Fastly
- Plus 2500+ more networks to explore!

---

## 📊 **Results**

Your scan results are saved in `~/output/[Provider]/`:

- **`frontable-*.txt`** → ✅ Working IPs for domain fronting
- **`frontable-*.log`** → 📜 Detailed scan logs

### **Understanding the Output:**
- `✔︎ 1.2.3.4` → ✅ **Perfect!** This IP supports domain fronting
- `✘ 1.2.3.4 (TLS handshake failed)` → ❌ No secure connection
- `✘ 1.2.3.4 (TLS OK, but curl test failed)` → ⚠️ TLS works but domain fronting failed

---

## 🛠️ **Using Results with Xray**

Example configuration snippet:

```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "YOUR_FRONTABLE_IP",  // ← Use IP from results
        "port": 443,
        "users": [{"encryption": "none", "id": "YOUR_UUID"}]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls", 
      "tlsSettings": {
        "serverName": "YOUR_DECOY_DOMAIN"  // ← Your decoy hostname
      },
      "wsSettings": {
        "host": "YOUR_DECOY_DOMAIN",
        "path": "YOUR_DECOY_PATH"          // ← Your decoy path
      }
    }
  }]
}
```

---

## ⚡ **Features**

| Feature | Description |
|---------|-------------|
| **🎯 Smart Scanning** | Tests both TLS handshake and domain fronting capability |
| **🔥 Popular ASNs** | Quick access to Cloudflare, Amazon, Google, Microsoft |
| **�� Keyword Search** | Find specific providers among 2500+ networks |
| **⚡ Parallel Processing** | 20+ concurrent jobs even on low-spec VPS |
| **🎨 Beautiful Logs** | Color-coded output with detailed debugging |
| **📁 Organized Results** | Clean folder structure with timestamps |
| **🖥️ Cross-Platform** | Works on macOS and Linux |

---

## 🐛 **Troubleshooting**

| Issue | Solution |
|-------|----------|
| **Permission error with masscan** | Enter your password when prompted (needs `sudo`) |
| **Missing dependencies** | Re-run installer: `bash <(curl -Ls https://raw.githubusercontent.com/mostafamoq/frontable-scanner/main/install.sh)` |
| **No results found** | Try different ASNs or verify your decoy URL is correct |
| **Command not found: frontable** | Open new terminal or run: `hash -r` |

---

## ℹ️ **What is Domain Fronting?**

Domain fronting is a technique that makes your internet traffic appear as if it's going to a popular, legitimate website (like Google or Cloudflare) while actually connecting to your intended destination. This helps bypass censorship and enhance privacy.

**This tool finds IP addresses that support this technique with your chosen decoy domain.**

---

<div align="center">

**🌟 Star this repo if it helped you bypass restrictions! 🌟**

[Report Issues](../../issues) • [Contribute](../../pulls) • [Discussions](../../discussions)

</div> 