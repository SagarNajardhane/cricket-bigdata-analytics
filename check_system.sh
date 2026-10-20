#!/usr/bin/env bash
# =====================================================================
# check_system.sh
# Cricket Big Data Project - System Compatibility Checker
# Checks all requirements for Phases 2 through 7 (Hadoop, Spark,
# Python, Streamlit, Git, Networking).
# =====================================================================

# Color codes for output
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[1;33m"; BLUE="\033[0;34m"; NC="\033[0m"

PASS=0; WARN=0; FAIL=0
RESULTS=()

# Helper to record a check
record() {
    local status="$1"; local item="$2"; local found="$3"; local min="$4"; local rec="$5"; local fix="$6"
    RESULTS+=("$status|$item|$found|$min|$rec|$fix")
    case "$status" in
        PASS) PASS=$((PASS+1));;
        WARN) WARN=$((WARN+1));;
        FAIL) FAIL=$((FAIL+1));;
    esac
}

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE} Cricket Big Data Project - System Compatibility Check${NC}"
echo -e "${BLUE}================================================================${NC}"

# ------------------- 1. WSL & Ubuntu -------------------
echo -e "\n${BLUE}[1/7] Checking WSL and Ubuntu...${NC}"
if grep -qi microsoft /proc/version; then
    WSL_VER=$(uname -r)
    if uname -r | grep -q "WSL2\|microsoft-standard"; then
        record "PASS" "WSL version" "WSL2 ($WSL_VER)" "WSL2" "WSL2" "-"
    else
        record "FAIL" "WSL version" "WSL1 ($WSL_VER)" "WSL2" "WSL2" "In PowerShell (admin): wsl --set-version Ubuntu 2"
    fi
else
    record "FAIL" "WSL" "Not WSL" "WSL2" "WSL2" "Install WSL2 from Microsoft Store"
fi

UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "unknown")
if [[ "$UBUNTU_VER" == "20.04" || "$UBUNTU_VER" == "22.04" || "$UBUNTU_VER" == "24.04" ]]; then
    record "PASS" "Ubuntu version" "$UBUNTU_VER" "20.04" "22.04" "-"
else
    record "WARN" "Ubuntu version" "$UBUNTU_VER" "20.04" "22.04" "Consider upgrading Ubuntu"
fi

# ------------------- 2. Hardware -------------------
echo -e "\n${BLUE}[2/7] Checking hardware (RAM, CPU, Disk)...${NC}"
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM_GB" -ge 8 ]; then
    record "PASS" "RAM available to WSL" "${RAM_GB} GB" "4 GB" "8 GB" "-"
elif [ "$RAM_GB" -ge 4 ]; then
    record "WARN" "RAM available to WSL" "${RAM_GB} GB" "4 GB" "8 GB" "Increase via C:\\Users\\<you>\\.wslconfig  (see fix below)"
else
    record "FAIL" "RAM available to WSL" "${RAM_GB} GB" "4 GB" "8 GB" "Edit .wslconfig to give WSL more RAM, then: wsl --shutdown"
fi

CPU_CORES=$(nproc)
if [ "$CPU_CORES" -ge 4 ]; then
    record "PASS" "CPU cores" "$CPU_CORES" "2" "4+" "-"
elif [ "$CPU_CORES" -ge 2 ]; then
    record "WARN" "CPU cores" "$CPU_CORES" "2" "4+" "Allocate more cores in .wslconfig (processors=4)"
else
    record "FAIL" "CPU cores" "$CPU_CORES" "2" "4+" "Allocate more cores in .wslconfig"
fi

DISK_FREE=$(df -BG ~ | awk 'NR==2{gsub("G","",$4); print $4}')
if [ "$DISK_FREE" -ge 20 ]; then
    record "PASS" "Free disk in \$HOME" "${DISK_FREE} GB" "10 GB" "20 GB" "-"
elif [ "$DISK_FREE" -ge 10 ]; then
    record "WARN" "Free disk in \$HOME" "${DISK_FREE} GB" "10 GB" "20 GB" "Clean up with: sudo apt clean"
else
    record "FAIL" "Free disk in \$HOME" "${DISK_FREE} GB" "10 GB" "20 GB" "Free disk space; Hadoop + Spark + data need room"
fi

# ------------------- 3. Java -------------------
echo -e "\n${BLUE}[3/7] Checking Java...${NC}"
if command -v java >/dev/null 2>&1; then
    JAVA_VER=$(java -version 2>&1 | head -n1 | awk -F'"' '{print $2}')
    JAVA_MAJOR=$(echo "$JAVA_VER" | awk -F. '{print $1}')
    if [ "$JAVA_MAJOR" = "1" ]; then JAVA_MAJOR=$(echo "$JAVA_VER" | awk -F. '{print $2}'); fi
    if [ "$JAVA_MAJOR" -ge 8 ] && [ "$JAVA_MAJOR" -le 11 ]; then
        record "PASS" "Java version" "$JAVA_VER" "8" "11 (for Hadoop 3)" "-"
    elif [ "$JAVA_MAJOR" -gt 11 ]; then
        record "WARN" "Java version" "$JAVA_VER" "8" "11" "Hadoop 3 works best with Java 8/11. Consider: sudo apt install openjdk-11-jdk"
    else
        record "FAIL" "Java version" "$JAVA_VER" "8" "11" "sudo apt install openjdk-11-jdk"
    fi
else
    record "FAIL" "Java" "not installed" "8" "11" "sudo apt update && sudo apt install -y openjdk-11-jdk"
fi

if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME" ]; then
    record "PASS" "JAVA_HOME" "$JAVA_HOME" "set" "set" "-"
else
    record "WARN" "JAVA_HOME" "not set" "set" "set" "Add to ~/.bashrc: export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(which java))))"
fi

# ------------------- 4. Python & Pip -------------------
echo -e "\n${BLUE}[4/7] Checking Python and pip...${NC}"
if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 --version | awk '{print $2}')
    PY_MAJOR=$(echo "$PY_VER" | awk -F. '{print $2}')
    if [ "$PY_MAJOR" -ge 8 ]; then
        record "PASS" "Python3" "$PY_VER" "3.8" "3.10+" "-"
    else
        record "WARN" "Python3" "$PY_VER" "3.8" "3.10+" "sudo apt install python3.10"
    fi
else
    record "FAIL" "Python3" "not installed" "3.8" "3.10+" "sudo apt install -y python3 python3-pip"
fi

if command -v pip3 >/dev/null 2>&1; then
    PIP_VER=$(pip3 --version | awk '{print $2}')
    record "PASS" "pip3" "$PIP_VER" "any" "latest" "-"
else
    record "FAIL" "pip3" "not installed" "any" "latest" "sudo apt install -y python3-pip"
fi

# Python packages for dashboard
echo -e "\n${BLUE}   Checking Python packages for dashboard (Phase 7)...${NC}"
for pkg in pandas matplotlib plotly streamlit pyspark; do
    if python3 -c "import $pkg" 2>/dev/null; then
        VER=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null)
        record "PASS" "Python pkg: $pkg" "$VER" "installed" "installed" "-"
    else
        record "WARN" "Python pkg: $pkg" "missing" "installed" "installed" "pip3 install $pkg  (we will install in Phase 2/7)"
    fi
done

# ------------------- 5. Git, SSH, wget/curl -------------------
echo -e "\n${BLUE}[5/7] Checking Git, SSH, wget/curl...${NC}"
if command -v git >/dev/null 2>&1; then
    record "PASS" "Git" "$(git --version | awk '{print $3}')" "2.0" "latest" "-"
else
    record "FAIL" "Git" "not installed" "2.0" "latest" "sudo apt install -y git"
fi

if command -v ssh >/dev/null 2>&1; then
    record "PASS" "ssh client" "installed" "any" "any" "-"
else
    record "FAIL" "ssh client" "missing" "any" "any" "sudo apt install -y openssh-client openssh-server"
fi

if systemctl is-active --quiet ssh 2>/dev/null || service ssh status >/dev/null 2>&1; then
    record "PASS" "ssh server" "running" "running" "running" "-"
else
    record "WARN" "ssh server" "not running" "running" "running" "sudo apt install -y openssh-server && sudo service ssh start  (needed for Hadoop)"
fi

if command -v wget >/dev/null 2>&1; then
    record "PASS" "wget" "installed" "any" "any" "-"
else
    record "WARN" "wget" "missing" "any" "any" "sudo apt install -y wget"
fi

if command -v curl >/dev/null 2>&1; then
    record "PASS" "curl" "installed" "any" "any" "-"
else
    record "WARN" "curl" "missing" "any" "any" "sudo apt install -y curl"
fi

if command -v unzip >/dev/null 2>&1; then
    record "PASS" "unzip" "installed" "any" "any" "-"
else
    record "WARN" "unzip" "missing" "any" "any" "sudo apt install -y unzip"
fi

# ------------------- 6. Hadoop & Spark -------------------
echo -e "\n${BLUE}[6/7] Checking Hadoop and Spark...${NC}"
if command -v hadoop >/dev/null 2>&1; then
    HV=$(hadoop version 2>/dev/null | head -n1 | awk '{print $2}')
    record "PASS" "Hadoop" "$HV" "3.3.x" "3.3.6" "-"
else
    record "WARN" "Hadoop" "not installed" "3.3.x" "3.3.6" "Will install in Phase 2"
fi

if command -v spark-submit >/dev/null 2>&1; then
    SV=$(spark-submit --version 2>&1 | grep -i "version" | head -n1 | awk '{print $NF}')
    record "PASS" "Spark" "$SV" "3.3.x" "3.5.x" "-"
else
    record "WARN" "Spark" "not installed" "3.3.x" "3.5.x" "Will install in Phase 2"
fi

# ------------------- 7. Internet & Ports -------------------
echo -e "\n${BLUE}[7/7] Checking Internet access and ports...${NC}"
for host in github.com cricsheet.org archive.apache.org; do
    if curl -s --head --max-time 5 "https://$host" | head -n1 | grep -q "200\|301\|302"; then
        record "PASS" "Internet: $host" "reachable" "reachable" "reachable" "-"
    else
        record "FAIL" "Internet: $host" "unreachable" "reachable" "reachable" "Check your network/proxy"
    fi
done

# Port checks (Hadoop NameNode UI 9870, YARN RM UI 8088, Spark UI 4040, Streamlit 8501)
for port in 9870 8088 4040 8501; do
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
        record "WARN" "Port $port" "in use" "free" "free" "Find process: sudo lsof -i :$port  and stop it"
    else
        record "PASS" "Port $port" "free" "free" "free" "-"
    fi
done

# ------------------- Results Table -------------------
echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE} RESULTS${NC}"
echo -e "${BLUE}================================================================${NC}"
printf "%-6s | %-28s | %-20s | %-10s | %-12s\n" "STATUS" "ITEM" "FOUND" "MIN" "RECOMMENDED"
echo "----------------------------------------------------------------------------------------------"
for row in "${RESULTS[@]}"; do
    IFS='|' read -r st item found min rec fix <<< "$row"
    case "$st" in
        PASS) color=$GREEN;;
        WARN) color=$YELLOW;;
        FAIL) color=$RED;;
    esac
    printf "${color}%-6s${NC} | %-28s | %-20s | %-10s | %-12s\n" "$st" "$item" "$found" "$min" "$rec"
done

echo -e "\n${BLUE}================================================================${NC}"
echo -e " Summary:  ${GREEN}PASS=$PASS${NC}   ${YELLOW}WARN=$WARN${NC}   ${RED}FAIL=$FAIL${NC}"
echo -e "${BLUE}================================================================${NC}"

# ------------------- Fixes section -------------------
if [ "$WARN" -gt 0 ] || [ "$FAIL" -gt 0 ]; then
    echo -e "\n${YELLOW}>>> FIXES REQUIRED <<<${NC}"
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r st item found min rec fix <<< "$row"
        if [ "$st" != "PASS" ]; then
            echo -e "${YELLOW}[$st]${NC} $item  ->  $fix"
        fi
    done

    echo -e "\n${YELLOW}>>> If RAM/CPU WARN or FAIL, edit this file on Windows:${NC}"
    echo "    C:\\Users\\<YourWindowsUser>\\.wslconfig"
    echo "    Contents:"
    echo "        [wsl2]"
    echo "        memory=8GB"
    echo "        processors=4"
    echo "        swap=4GB"
    echo "    Then in PowerShell:  wsl --shutdown   (and reopen Ubuntu)"
fi

echo -e "\n${GREEN}Done.${NC}"
