# 🎯 Domain Fronting IP Scanner

> **Find special IPs for domain fronting to bypass internet restrictions and enhance privacy.**
> **Now supports custom ports and XHTTP protocol!** 🚀

---

## 🆕 **What's New in Latest Version**

### **🔌 Multi-Protocol Support**
- ✅ **WebSocket (WS)** - Traditional WebSocket connections
- ✅ **XHTTP** - HTTP/2 multiplexing protocol (NEW!)

### **🎯 Smart Port Detection**
- ✅ **Auto-extracts ports** from your decoy URL
- ✅ **Custom ports supported**: 2096, 8443, 9999, or any port
- ✅ **Default fallbacks**: HTTPS (443), HTTP (80)

### **🧠 Intelligent Testing**
- ✅ **Protocol-specific validation**
- ✅ **Accepts all valid HTTP codes** (200, 400, 404, 500, etc.)
- ✅ **Enhanced detection accuracy**

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

The tool will interactively guide you through:

### **1. 🎭 Enter Your Decoy URL**
Examples of supported formats:
```
https://example.com/ws                    → Port 443 (HTTPS default)
https://example.com:2096/xxx              → Port 2096 (custom)
https://example.com:8443/ws?xxx           → Port 8443 (custom)
http://example.com:8080/api               → Port 8080 (custom)
```

### **2. 🔌 Choose Protocol Type**
```
🔌 Select the target protocol:
  1) WebSocket (WS) - Traditional WebSocket connections
  2) XHTTP - HTTP/2 multiplexing protocol
```

### **3. 🏢 Provider Name**
For organizing results (e.g., "MCI", "MKH", "Cloudflare")

### **4. 🌐 ASN Selection**
Choose from popular providers or search all networks

### **Popular ASNs Available:**
- 🔥 **AS13335** Cloudflare, Inc.
- 🔥 **AS16509** Amazon.com, Inc. 
- 🔥 **AS15169** Google LLC
- 🔥 **AS8075** Microsoft Corporation
- 🔥 **AS54113** Fastly
- Plus 2500+ more networks to explore!

---

## 📊 **Enhanced Results**

Your scan results are saved in `~/output/[Provider]/`:

- **`frontable-*.txt`** → ✅ Working IPs for domain fronting
- **`frontable-*.log`** → 📜 Detailed scan logs with protocol info

### **Understanding the New Output:**
```bash
✔︎ 1.2.3.4 (WebSocket fronting works)           → ✅ Perfect WS support!
✔︎ 5.6.7.8 (XHTTP fronting works, HTTP 404)    → ✅ Perfect XHTTP support!
✘ 9.8.7.6 (TLS OK, but XHTTP connection failed) → ❌ Protocol incompatible
✘ 1.1.1.1 (TLS handshake failed)                → ❌ No secure connection
```

---

## 🛠️ **Using Results with Xray**

### **WebSocket Configuration:**
```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "YOUR_FRONTABLE_IP",  // ← Use IP from WS results
        "port": 443,  // ← Or your custom port
        "users": [{"encryption": "none", "id": "YOUR_UUID"}]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls", 
      "tlsSettings": {
        "serverName": "YOUR_DECOY_DOMAIN"
      },
      "wsSettings": {
        "host": "YOUR_DECOY_DOMAIN",
        "path": "YOUR_DECOY_PATH"
      }
    }
  }]
}
```

### **XHTTP Configuration:**
```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "YOUR_FRONTABLE_IP",  // ← Use IP from XHTTP results
        "port": 2096,  // ← Your custom port (e.g., 2096, 8443)
        "users": [{"encryption": "none", "id": "YOUR_UUID"}]
      }]
    },
    "streamSettings": {
      "network": "xhttp",
      "security": "tls",
      "tlsSettings": {
        "serverName": "YOUR_DECOY_DOMAIN",
        "alpn": ["h2", "http/1.1"]
      },
      "xhttpSettings": {
        "host": "YOUR_DECOY_DOMAIN",
        "path": "YOUR_DECOY_PATH",
        "mode": "auto"
      }
    }
  }]
}
```

---

## ⚡ **Enhanced Features**

| Feature | Description |
|---------|-------------|
| **🔌 Multi-Protocol** | WebSocket + XHTTP support with intelligent detection |
| **🎯 Smart Port Detection** | Auto-extracts ports from URLs (443, 2096, 8443, etc.) |
| **🧠 Protocol-Specific Testing** | Tailored validation for each protocol type |
| **🎨 Enhanced Logging** | Protocol and port info in colored output |
| **🔥 Popular ASNs** | Quick access to Cloudflare, Amazon, Google, Microsoft |
| **🔍 Keyword Search** | Find specific providers among 2500+ networks |
| **⚡ Parallel Processing** | 20+ concurrent jobs even on low-spec VPS |
| **📁 Organized Results** | Clean folder structure with timestamps |
| **🖥️ Cross-Platform** | Works on macOS and Linux |

---

## 🎯 **Protocol-Specific Examples**

### **VLESS WebSocket:**
```
Input URL: https://cdn.example.com/wsxxx
→ Protocol: WebSocket
→ Port: 443 (default HTTPS)
→ Tests for: HTTP 400 "Bad Request" response
```

### **VLESS XHTTP:**
```
Input URL: https://cdn.example.com:2096/xxxx
→ Protocol: XHTTP  
→ Port: 2096 (custom)
→ Tests for: Any valid HTTP response (200, 404, 403, etc.)
```

---

## 🐛 **Troubleshooting**

| Issue | Solution |
|-------|----------|
| **Permission error with masscan** | Enter your password when prompted (needs `sudo`) |
| **Missing dependencies** | Re-run installer: `bash <(curl -Ls https://raw.githubusercontent.com/mostafamoq/frontable-scanner/main/install.sh)` |
| **No results found** | Try different ASNs or verify your decoy URL/protocol is correct |
| **Command not found: frontable** | Open new terminal or run: `hash -r` |
| **XHTTP not working** | Ensure your server supports HTTP/2 and the correct path |

---

## ℹ️ **What is Domain Fronting?**

Domain fronting is a technique that makes your internet traffic appear as if it's going to a popular, legitimate website (like Google or Cloudflare) while actually connecting to your intended destination. This helps bypass censorship and enhance privacy.

**This tool finds IP addresses that support this technique with your chosen decoy domain and protocol.**

### **Why Multi-Protocol Support Matters:**
- **WebSocket**: Widely supported, stable connections
- **XHTTP**: Modern HTTP/2 multiplexing, better performance
- **Custom Ports**: Bypass port-based filtering (2096, 8443, etc.)

---

<div align="center">

**🌟 Star this repo if it helped you bypass restrictions! 🌟**

**New: XHTTP + Multi-Port Support!** 🚀

[Report Issues](../../issues) • [Contribute](../../pulls) • [Discussions](../../discussions)

</div> 