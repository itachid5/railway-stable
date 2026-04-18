FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV TZ="Asia/Dhaka"

# Keep package managers quieter and cleaner
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV NPM_CONFIG_AUDIT=false
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_CACHE=/tmp/.npm-cache

# --------------------------------------------------
# Base system packages
# --------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils \
    lsof htop jq speedtest-cli unzip tree python3 python3-pip python3-venv \
    ca-certificates gnupg \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# --------------------------------------------------
# Install Node.js LTS + Codex at build time
# --------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm i -g @openai/codex --cache /tmp/.npm-cache --no-audit --no-fund \
    && npm cache clean --force \
    && rm -rf /tmp/.npm-cache /root/.npm /root/.cache/npm /root/.cache/node-gyp \
    && apt-get purge -y --auto-remove gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# --------------------------------------------------
# SSH + users
# --------------------------------------------------
RUN mkdir -p /var/run/sshd && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# --------------------------------------------------
# Disable default MOTD noise
# --------------------------------------------------
RUN rm -rf /etc/update-motd.d/* && \
    rm -f /etc/legal && \
    rm -f /etc/motd && \
    touch /home/devuser/.hushlogin && \
    touch /root/.hushlogin

# --------------------------------------------------
# Prompt styling
# --------------------------------------------------
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# --------------------------------------------------
# Main shell setup
# --------------------------------------------------
RUN cat > /tmp/setup.sh <<'EOF'

# ==========================================
# 🚀 SYSTEM ALIASES (BUILT-IN)
# ==========================================

# Nav & Files
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias md='mkdir -p'
alias sz='du -sh * 2>/dev/null | sort -hr'
alias tree='tree -C'
alias f='find . -name'
alias grep='grep --color=auto'
alias h='history'
alias findbig='find . -type f -size +50M -exec ls -lh {} + 2>/dev/null | awk "{ print \$9 \": \" \$5 }"'

# 🌟 Extra File & Nav Shortcuts
alias dsize='du -h --max-depth=1 | sort -hr'
alias chmodx='chmod +x'
alias chownme='sudo chown -R $USER:$USER .'
alias path='echo -e ${PATH//:/\\n}'

# System
alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean && reclaimram'
alias mem='ram'
alias hostmem='free -h'
alias df='df -h'
alias top='htop'
alias ports='sudo netstat -tulpn'
alias logs='sudo tail -f /var/log/syslog'
alias rst='source ~/.bashrc && echo -e "\e[1;32m✔ Terminal Reloaded!\e[0m"'

# 🌟 Extra System Shortcuts
alias sysinfo='cat /etc/os-release'
alias cpuinfo='lscpu'
alias myports='ss -tuln'
alias histg='history | grep'

# Network & VPN
alias myip='echo -e "\n\e[1;36m🌐 IP Details:\e[0m"; curl -s ipinfo.io; echo'
alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple'
alias ping='ping -c 4'
alias ts='sudo tailscale status'

# 🌟 Extra Network Shortcuts
alias pinger='ping -c 4 8.8.8.8'
alias serve='python3 -m http.server 8000'

# Dev & Tools
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph -n 10'
alias get='wget -c'
alias api='curl -s'
alias weather='curl -s wttr.in/Dhaka?0'

# 🌟 Python Venv Shortcuts
alias mkv='python3 -m venv .venv && echo -e "\e[1;32m✔ .venv created successfully!\e[0m"'
alias onv='source .venv/bin/activate 2>/dev/null || echo -e "\e[1;31m✘ .venv not found! Run mkv first.\e[0m"'
alias offv='deactivate 2>/dev/null || echo -e "\e[1;33mℹ No active virtual environment to deactivate.\e[0m"'

# Apps Management
alias apps='echo -e "\n\e[1;36m▶ Node/Python/Codex Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[c]odex|[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"'
alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"'
alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"'
alias kcodex='sudo pkill -f codex 2>/dev/null; echo -e "\e[1;32m✔ All Codex processes stopped.\e[0m"'

# ==========================================
# 🛠️ CUSTOM SHORTCUT MANAGER
# ==========================================

CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts"
if [ -f "$CUSTOM_ALIAS_FILE" ]; then
    source "$CUSTOM_ALIAS_FILE"
fi

function addcmd() {
    echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name (e.g., gohome) : " S_NAME
    if [ -z "$S_NAME" ]; then echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; fi

    if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' already exists! Please choose another name.\e[0m"
        return 1
    fi

    read -p "Command to run (e.g., cd ~)  : " S_CMD
    if [ -z "$S_CMD" ]; then echo -e "\e[1;31m✘ Cancelled. Command cannot be empty.\e[0m"; return 1; fi

    echo "alias $S_NAME='$S_CMD'" >> "$CUSTOM_ALIAS_FILE"
    eval "alias $S_NAME='$S_CMD'"
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' has been created and is ready to use!\e[0m\n"
}

function delcmd() {
    echo -e "\n\e[1;31m🗑️ Delete a Custom Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name to delete : " S_NAME
    if [ -z "$S_NAME" ]; then echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; fi

    if ! grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' not found in your custom list!\e[0m"
        return 1
    fi

    sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE"
    unalias "$S_NAME" 2>/dev/null
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' has been successfully deleted!\e[0m\n"
}

# ==========================================
# ⚡ THE PERFECTLY ALIGNED COMMAND MENU
# ==========================================

function pcmd() {
    printf "   \e[1;32m%-12s\e[0m : %s\n" "$1" "$2"
}

function cmds() {
    echo -e "\n\e[1;37m⚡ ALL MAGICAL SHORTCUTS ⚡\e[0m"
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m"

    echo -e "\e[1;33m📁 Navigation & Files\e[0m"
    pcmd "c" "Clear screen"
    pcmd ".." "Go back 1 folder"
    pcmd "..." "Go back 2 folders"
    pcmd "ll" "List files with details & sizes"
    pcmd "sz" "Show size of folders/files in current dir"
    pcmd "md" "Make a new directory (e.g., md newfolder)"
    pcmd "mkcd <dir>" "Make a directory and instantly enter it 🌟"
    pcmd "tree" "Show files in a visual tree structure"
    pcmd "dsize" "List size of all sub-folders cleanly 🌟"
    pcmd "chownme" "Take ownership of current directory 🌟"
    pcmd "chmodx" "Make a file executable quickly 🌟"
    pcmd "ex <file>" "Extract ANY archive (zip, tar, gz, etc.)"
    pcmd "findbig" "Find files larger than 50MB"
    pcmd "findtext" "Search inside all files for a specific text 🌟"

    echo -e "\n\e[1;33m💻 System & Processes\e[0m"
    pcmd "up" "Update and upgrade OS packages"
    pcmd "clean" "Autoremove + apt clean + reclaimram"
    pcmd "mem" "Same as ram (container-accurate memory view)"
    pcmd "hostmem" "Raw free -h output from inside container"
    pcmd "ram" "Container RAM summary + root-cause hint"
    pcmd "ramtop" "Top 15 processes by RSS"
    pcmd "ramwhy" "Explain what is filling RAM"
    pcmd "reclaimram" "Clean package caches and try to reclaim RAM"
    pcmd "cachefiles" "Show common cache directories"
    pcmd "df" "Show Disk space usage"
    pcmd "top" "Open Task Manager (htop)"
    pcmd "cpuinfo" "Show CPU information 🌟"
    pcmd "sysinfo" "Show OS version details 🌟"
    pcmd "ports" "List all currently open ports"
    pcmd "logs" "View live system logs"
    pcmd "rst" "Reload terminal settings (bashrc)"
    pcmd "h" "Show command history"
    pcmd "histg <txt>" "Search command history for specific text 🌟"

    echo -e "\n\e[1;33m🎯 App Management\e[0m"
    pcmd "apps" "List all running Codex/Node/Python apps"
    pcmd "kn" "Kill all Node.js apps"
    pcmd "kp" "Kill all Python apps"
    pcmd "kcodex" "Kill all Codex processes"
    pcmd "kport <no>" "Kill app running on a specific port"

    echo -e "\n\e[1;33m🌐 Network & VPN\e[0m"
    pcmd "cc" "Connect to Tailscale VPN"
    pcmd "cs" "Disconnect & Stop Tailscale VPN"
    pcmd "ts" "Show Tailscale Status"
    pcmd "myip" "Show Public IP and full location info"
    pcmd "pinger" "Quickly check internet connectivity 🌟"
    pcmd "speed" "Test Internet Download/Upload speed"
    pcmd "serve" "Instantly host current folder on port 8000 🌟"

    echo -e "\n\e[1;33m🛠️ Tools & Dev\e[0m"
    pcmd "weather" "Show current weather in Dhaka"
    pcmd "gs, ga, gc" "Git Status, Add, Commit"
    pcmd "addcmd" "Create a personal custom shortcut!"
    pcmd "delcmd" "Delete a personal custom shortcut!"
    pcmd "mkv" "Create new .venv (python3 -m venv) 🌟"
    pcmd "onv" "Activate .venv (source .venv/bin/...) 🌟"
    pcmd "offv" "Deactivate current virtual env 🌟"
    pcmd "sv" "Smart Activate Virtual Env (venv/.venv/env) 🌟"
    pcmd "dcodex" "Codex is preinstalled; show version/status 🌟"
    pcmd "dpy" "Check Python, Pip & Virtualenv status 🌟"
    pcmd "dgo" "Auto-install Golang (runtime, may raise cache) 🌟"
    pcmd "djava" "Auto-install Java 17 LTS (runtime, may raise cache) 🌟"

    echo -e "\n\e[1;35m👤 My Personal Shortcuts\e[0m"
    if [ -f "$CUSTOM_ALIAS_FILE" ] && [ -s "$CUSTOM_ALIAS_FILE" ]; then
        cat "$CUSTOM_ALIAS_FILE" | sed "s/alias //g" | sed "s/='/|/g" | sed "s/'//g" | while IFS='|' read -r name cmd; do
            pcmd "$name" "$cmd"
        done
    else
        echo -e "   \e[90mNo personal shortcuts yet. Type 'addcmd' to create one.\e[0m"
    fi
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# Helpers
# ==========================================

function mkcd() { mkdir -p "$1" && cd "$1"; }
function findtext() { grep -rnw . -e "$1"; }

function kport() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: kport <port>\e[0m"; return 1; fi
    PID=$(sudo lsof -t -i:$1)
    if [ -z "$PID" ]; then
        echo -e "\e[1;33mℹ Port $1 is free\e[0m"
    else
        sudo kill -9 $PID
        echo -e "\e[1;32m✔ Killed process on port $1\e[0m"
    fi
}

function ex() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: ex <filename>\e[0m"; return 1; fi
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar e "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.zip) unzip "$1" ;;
            *) echo -e "\e[1;31m✘ Cannot extract '$1'\e[0m" ;;
        esac
    else
        echo -e "\e[1;31m✘ '$1' is not a valid file\e[0m"
    fi
}

# ==========================================
# 🌟 DEV SHORTCUTS
# ==========================================

function sv() {
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        echo -e "\e[1;32m✔ venv activated!\e[0m"
    elif [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
        echo -e "\e[1;32m✔ .venv activated!\e[0m"
    elif [ -f "env/bin/activate" ]; then
        source env/bin/activate
        echo -e "\e[1;32m✔ env activated!\e[0m"
    else
        echo -e "\e[1;31m✘ No virtual environment (venv, .venv, env) found in this directory!\e[0m"
        echo -e "\e[1;33mℹ Run 'mkv' to create one.\e[0m"
    fi
}

# Codex is already baked into the image
function dcodex() {
    echo -e "\n\e[1;36m🤖 Codex Status\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    if command -v codex >/dev/null 2>&1; then
        echo -e "\e[1;32m✔ Codex is already installed in this image.\e[0m"
        echo -e "\e[1;36mCodex Version:\e[0m $(codex --version 2>/dev/null || echo installed)"
        echo -e "\e[1;36mNode Version:\e[0m $(node -v 2>/dev/null || echo missing)"
        echo -e "\e[1;36mNPM Version:\e[0m $(npm -v 2>/dev/null || echo missing)"
        echo -e "\e[1;33mℹ Run 'codex' manually when you want to start it.\e[0m"
    else
        echo -e "\e[1;31m✘ Codex not found. Rebuild the image.\e[0m"
        return 1
    fi
    echo
}

function dpy() {
    echo -e "\n\e[1;36m🐍 Python Environment Status\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"

    NEED_PKGS=""
    command -v pip3 >/dev/null 2>&1 || NEED_PKGS="$NEED_PKGS python3-pip"
    python3 -m venv --help >/dev/null 2>&1 || NEED_PKGS="$NEED_PKGS python3-venv"

    if [ -z "$NEED_PKGS" ]; then
        echo -e "\e[1;32m✔ Python, pip and venv are already installed.\e[0m"
        echo -e "\e[1;36mPython Version:\e[0m $(python3 --version 2>&1)"
        echo -e "\e[1;36mPip Version:\e[0m $(pip3 --version 2>&1)"
        return 0
    fi

    echo -e "\e[1;33m⚠ Missing packages detected. Runtime install can raise file cache and Railway RAM graph.\e[0m"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends $NEED_PKGS
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin
    python3 -m pip cache purge >/dev/null 2>&1 || true
    sync

    echo -e "\e[1;32m✔ Python environment is ready!\e[0m"
    echo -e "\e[1;36mPython Version:\e[0m $(python3 --version 2>&1)"
    echo -e "\e[1;36mPip Version:\e[0m $(pip3 --version 2>&1)"
}

function dgo() {
    echo -e "\n\e[1;36m🐹 Installing Golang...\e[0m"
    echo -e "\e[1;33m⚠ Runtime install can raise file cache and Railway RAM graph.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends golang
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Go installed successfully!\e[0m"
    go version
}

function djava() {
    echo -e "\n\e[1;36m☕ Installing Java 17 LTS...\e[0m"
    echo -e "\e[1;33m⚠ Runtime install can raise file cache and Railway RAM graph.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Java installed successfully!\e[0m"
    java -version
}

# ==========================================
# 📊 RAM / MEMORY TOOLS (CONTAINER ACCURATE)
# ==========================================

_b2h() {
  awk -v b="${1:-0}" 'BEGIN{
    split("B KB MB GB TB",u," ");
    i=1;
    while (b>=1024 && i<5) { b/=1024; i++ }
    printf "%.1f %s", b, u[i]
  }'
}

_cg_mode() {
  if [ -f /sys/fs/cgroup/memory.current ]; then
    echo "v2"
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
    echo "v1"
  else
    echo ""
  fi
}

_cg_base() {
  if [ -f /sys/fs/cgroup/memory.current ]; then
    echo "/sys/fs/cgroup"
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
    echo "/sys/fs/cgroup/memory"
  else
    echo ""
  fi
}

_cg_read() {
  [ -f "$1" ] && cat "$1" 2>/dev/null || echo 0
}

_cg_stat() {
  local key="$1" base="$(_cg_base)" mode="$(_cg_mode)" alt=""
  [ -z "$base" ] && { echo 0; return; }

  if [ "$mode" = "v2" ]; then
    awk -v k="$key" '$1==k {print $2}' "$base/memory.stat" 2>/dev/null | head -n 1
    return
  fi

  case "$key" in
    anon) alt="rss" ;;
    file) alt="cache" ;;
    shmem) alt="shmem" ;;
    slab) alt="slab" ;;
    slab_reclaimable) alt="slab_reclaimable" ;;
    pagetables) alt="pgtable" ;;
    kernel_stack) alt="kernel_stack" ;;
    sock) alt="sock" ;;
    *) alt="$key" ;;
  esac

  awk -v k="$alt" '$1==k {print $2}' "$base/memory.stat" 2>/dev/null | head -n 1
}

function ramtop() {
  echo -e "\n\e[1;36m📋 Top Processes by RSS\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-7s │ %-8s │ %-6s │ %-10s │ %s\n" "PID" "USER" "MEM%" "USED" "COMMAND"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  ps -eo pid=,user=,%mem=,rss=,comm= --sort=-rss | head -n 15 | while read -r pid user mem rss comm; do
    used_bytes=$((rss * 1024))
    used="$(_b2h "$used_bytes")"
    printf "  %-7s │ %-8.8s │ %-6s │ %-10s │ %s\n" "$pid" "$user" "${mem}%" "$used" "$comm"
  done
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function ramwhy() {
  local base used limit anon file shmem slab slab_reclaimable pgt kstack sock rss codex_proc node_proc py_proc reclaimable
  base="$(_cg_base)"
  [ -z "$base" ] && { echo "cgroup memory info not found"; return 1; }

  if [ -f "$base/memory.current" ]; then
    used=$(_cg_read "$base/memory.current")
    limit=$(_cg_read "$base/memory.max")
  else
    used=$(_cg_read "$base/memory.usage_in_bytes")
    limit=$(_cg_read "$base/memory.limit_in_bytes")
  fi

  anon=${_CG_ANON:-$(_cg_stat anon)}; [ -z "$anon" ] && anon=0
  file=${_CG_FILE:-$(_cg_stat file)}; [ -z "$file" ] && file=0
  shmem=${_CG_SHMEM:-$(_cg_stat shmem)}; [ -z "$shmem" ] && shmem=0
  slab=${_CG_SLAB:-$(_cg_stat slab)}; [ -z "$slab" ] && slab=0
  slab_reclaimable=${_CG_SLAB_REC:-$(_cg_stat slab_reclaimable)}; [ -z "$slab_reclaimable" ] && slab_reclaimable=0
  pgt=${_CG_PGT:-$(_cg_stat pagetables)}; [ -z "$pgt" ] && pgt=0
  kstack=${_CG_KSTACK:-$(_cg_stat kernel_stack)}; [ -z "$kstack" ] && kstack=0
  sock=${_CG_SOCK:-$(_cg_stat sock)}; [ -z "$sock" ] && sock=0
  rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print s*1024}')
  [ -z "$rss" ] && rss=0
  reclaimable=$((file + slab_reclaimable))

  codex_proc=$(pgrep -af '(^|/)(codex)( |$)|@openai/codex' 2>/dev/null | head -n 3)
  node_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[n]ode|[n]pm' | head -n 5)
  py_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[p]ython' | head -n 5)

  echo -e "\n\e[1;35m🔎 RAM Diagnosis\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

  if [ "$file" -gt "$anon" ] && [ "$file" -gt $((150*1024*1024)) ]; then
    echo -e "\e[1;33mMain Cause:\e[0m File/Page cache is dominating memory."
    echo -e "This usually happens after installs, archive extraction, or heavy file scanning."
    echo -e "Likely reclaimable cache now: \e[1;36m$(_b2h "$reclaimable")\e[0m"
  elif [ "$anon" -gt $((200*1024*1024)) ]; then
    echo -e "\e[1;33mMain Cause:\e[0m Real process/application memory is high (anon memory)."
    echo -e "That means one or more running processes are actually holding RAM."
  else
    echo -e "\e[1;33mMain Cause:\e[0m Mixed usage."
    echo -e "Some RAM is real process memory, some is kernel/cache overhead."
  fi

  if [ -n "$codex_proc" ]; then
    echo -e "\n\e[1;31m⚠ Codex appears to be running:\e[0m"
    echo "$codex_proc"
  fi

  if [ -n "$node_proc" ]; then
    echo -e "\n\e[1;36mNode/NPM related processes:\e[0m"
    echo "$node_proc"
  fi

  if [ -n "$py_proc" ]; then
    echo -e "\n\e[1;36mPython related processes:\e[0m"
    echo "$py_proc"
  fi

  echo -e "\n\e[1;32mWhat to do now:\e[0m"
  echo -e "  1) Run \e[1;36mram\e[0m and check File Cache vs Anon Memory"
  echo -e "  2) Run \e[1;36mcachefiles\e[0m to see cache folders"
  echo -e "  3) If File Cache is high, run \e[1;36mreclaimram\e[0m"
  echo -e "  4) If Anon/Process memory is high, run \e[1;36mramtop\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function ram() {
  local base used limit anon file shmem slab slab_reclaimable pgt kstack sock rss free limit_txt free_txt used_pct reclaimable
  base="$(_cg_base)"
  [ -z "$base" ] && { echo "cgroup memory info not found"; return 1; }

  if [ -f "$base/memory.current" ]; then
    used=$(_cg_read "$base/memory.current")
    limit=$(_cg_read "$base/memory.max")
  else
    used=$(_cg_read "$base/memory.usage_in_bytes")
    limit=$(_cg_read "$base/memory.limit_in_bytes")
  fi

  anon=$(_cg_stat anon); [ -z "$anon" ] && anon=0
  file=$(_cg_stat file); [ -z "$file" ] && file=0
  shmem=$(_cg_stat shmem); [ -z "$shmem" ] && shmem=0
  slab=$(_cg_stat slab); [ -z "$slab" ] && slab=0
  slab_reclaimable=$(_cg_stat slab_reclaimable); [ -z "$slab_reclaimable" ] && slab_reclaimable=0
  pgt=$(_cg_stat pagetables); [ -z "$pgt" ] && pgt=0
  kstack=$(_cg_stat kernel_stack); [ -z "$kstack" ] && kstack=0
  sock=$(_cg_stat sock); [ -z "$sock" ] && sock=0
  rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print s*1024}')
  [ -z "$rss" ] && rss=0
  reclaimable=$((file + slab_reclaimable))

  export _CG_ANON="$anon" _CG_FILE="$file" _CG_SHMEM="$shmem" _CG_SLAB="$slab" _CG_SLAB_REC="$slab_reclaimable" _CG_PGT="$pgt" _CG_KSTACK="$kstack" _CG_SOCK="$sock"

  if [[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -gt 0 ]; then
    free=$((limit - used))
    [ "$free" -lt 0 ] && free=0
    limit_txt="$(_b2h "$limit")"
    free_txt="$(_b2h "$free")"
    used_pct=$(awk -v u="$used" -v l="$limit" 'BEGIN { if (l>0) printf "%.1f%%", (u/l)*100; else print "-" }')
  else
    limit_txt="unlimited"
    free_txt="-"
    used_pct="-"
  fi

  echo -e "\n\e[1;36m📊 RAM (Container Accurate)\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-20s : %s\n" "Cgroup Total" "$(_b2h "$used")"
  printf "  %-20s : %s\n" "Memory Limit" "$limit_txt"
  printf "  %-20s : %s\n" "Free to Limit" "$free_txt"
  printf "  %-20s : %s\n" "Usage Percent" "$used_pct"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-20s : %s\n" "Process RSS Sum" "$(_b2h "$rss")"
  printf "  %-20s : %s\n" "Anon Memory" "$(_b2h "$anon")"
  printf "  %-20s : %s\n" "File Cache" "$(_b2h "$file")"
  printf "  %-20s : %s\n" "Slab" "$(_b2h "$slab")"
  printf "  %-20s : %s\n" "Slab Reclaimable" "$(_b2h "$slab_reclaimable")"
  printf "  %-20s : %s\n" "Likely Reclaimable" "$(_b2h "$reclaimable")"
  printf "  %-20s : %s\n" "Shared Memory" "$(_b2h "$shmem")"
  printf "  %-20s : %s\n" "Page Tables" "$(_b2h "$pgt")"
  printf "  %-20s : %s\n" "Kernel Stack" "$(_b2h "$kstack")"
  printf "  %-20s : %s\n" "Socket Buffers" "$(_b2h "$sock")"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

  if [ "$file" -gt "$anon" ] && [ "$file" -gt $((150*1024*1024)) ]; then
    echo -e "\e[1;33mHint:\e[0m Most RAM is in file/page cache, not in active apps."
  elif [ "$anon" -gt $((200*1024*1024)) ]; then
    echo -e "\e[1;33mHint:\e[0m Active processes are the main RAM users right now."
  else
    echo -e "\e[1;33mHint:\e[0m RAM usage is mixed between processes and cache."
  fi

  echo -e "\n\e[1;36mRun these for details:\e[0m  \e[1;32mramtop\e[0m  |  \e[1;32mramwhy\e[0m  |  \e[1;32mcachefiles\e[0m  |  \e[1;32mreclaimram\e[0m\n"
}

function cachefiles() {
  echo -e "\n\e[1;36m🗂 Common Cache Directories\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  du -sh \
    /var/cache/apt \
    /var/lib/apt/lists \
    "$HOME/.cache" \
    "$HOME/.cache/pip" \
    "$HOME/.cache/npm" \
    "$HOME/.cache/node-gyp" \
    "$HOME/.npm" \
    /tmp/.npm-cache \
    /var/tmp \
    2>/dev/null | sort -hr
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function reclaimram() {
  echo -e "\n\e[1;33m🧹 Cleaning package/cache files...\e[0m"

  npm cache clean --force >/dev/null 2>&1 || true
  python3 -m pip cache purge >/dev/null 2>&1 || true
  sudo apt-get clean >/dev/null 2>&1 || true

  rm -rf \
    "$HOME/.npm" \
    "$HOME/.cache/npm" \
    "$HOME/.cache/node-gyp" \
    "$HOME/.cache/pip" \
    /tmp/.npm-cache \
    /tmp/pip-* \
    /tmp/pip-build-* \
    /tmp/pip-install-* \
    /var/tmp/* \
    2>/dev/null || true

  sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin 2>/dev/null || true

  sync

  if sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null; then
    echo -e "\e[1;32m✔ Linux page cache dropped.\e[0m"
  else
    echo -e "\e[1;33mℹ Cache files were removed, but this container is not allowed to force-drop kernel page cache.\e[0m"
    echo -e "\e[1;33mℹ If file cache stays high, restart/redeploy the container for the cleanest reset.\e[0m"
  fi

  ram
}

# ==========================================
# 📊 UI & DASHBOARD FUNCTIONS
# ==========================================

function custom_motd() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    KERNEL_VERSION=$(uname -r)
    ARCH=$(uname -m)
    CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown Virtual CPU"

    LAST_LOGIN_FILE="$HOME/.last_login_info"
    if [ -f "$LAST_LOGIN_FILE" ]; then
        LAST_LOGIN_DATA=$(cat "$LAST_LOGIN_FILE")
        LAST_LOGIN_TIME=$(echo "$LAST_LOGIN_DATA" | cut -d'|' -f1)
        LAST_LOGIN_IP=$(echo "$LAST_LOGIN_DATA" | cut -d'|' -f2)
    else
        LAST_LOGIN_TIME="First Login"
        LAST_LOGIN_IP="---"
    fi

    CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
    echo "$(date +"%A, %d %B %Y %I:%M:%S %p")|${CURRENT_IP:-Local}" > "$LAST_LOGIN_FILE"

    UPTIME_SEC=$(ps -o etimes= -p 1 2>/dev/null | xargs)
    if [ -n "$UPTIME_SEC" ] && [[ "$UPTIME_SEC" =~ ^[0-9]+$ ]]; then
        d=$((UPTIME_SEC / 86400))
        h=$(((UPTIME_SEC % 86400) / 3600))
        m=$(((UPTIME_SEC % 3600) / 60))
        if [ $d -gt 0 ]; then
            MY_UPTIME="${d} days, ${h} hours, ${m} mins"
        elif [ $h -gt 0 ]; then
            MY_UPTIME="${h} hours, ${m} mins"
        else
            MY_UPTIME="${m} mins"
        fi
    else
        MY_UPTIME="Just started"
    fi

    echo -e "\e[1;36m╭────────────────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "\e[1;36m│ \e[1;37m🔥 Welcome to Phoenix Server 🔥\e[0m                                        "
    echo -e "\e[1;36m├────────────────────────────────────────────────────────────────────────┤\e[0m"
    echo -e "\e[1;36m│ \e[1;32m💻 OS\e[0m         : ${OS_VERSION}"
    echo -e "\e[1;36m│ \e[1;32m🐧 Kernel\e[0m     : ${KERNEL_VERSION} (${ARCH})"
    echo -e "\e[1;36m│ \e[1;32m⚙️  CPU\e[0m        : ${CPU_MODEL}"
    echo -e "\e[1;36m│ \e[1;32m⏳ Uptime\e[0m     : ${MY_UPTIME}"
    echo -e "\e[1;36m│ \e[1;32m🕒 Last Login\e[0m : ${LAST_LOGIN_TIME}"
    echo -e "\e[1;36m│ \e[1;32m🌐 Login IP\e[0m   : ${LAST_LOGIN_IP}"
    echo -e "\e[1;36m╰────────────────────────────────────────────────────────────────────────╯\e[0m"
}

function mm() {
  local base used limit free used_mb limit_mb free_mb used_pct
  local anon file rss reclaimable slab_rec
  local cpu_used cpu_pct
  local disk_total disk_used disk_free
  local home_items
  local C_C="\e[36m" C_G="\e[90m" C_W="\e[1;37m" C_R="\e[0m"

  echo -e "\n${C_W}▶ SYSTEM MONITOR (Container Accurate)${C_R}\n${C_G}------------------------------------------------------------${C_R}"

  print_row() {
    echo -e " $1   ${C_W}$(printf "%-5s" "$2")${C_R} ${C_G}::${C_R}  ${C_C}$(printf "%-13s" "$3")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-13s" "$4")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-14s" "$5")${C_R}"
  }

  base="$(_cg_base)"
  if [ -n "$base" ]; then
    if [ -f "$base/memory.current" ]; then
      used=$(_cg_read "$base/memory.current")
      limit=$(_cg_read "$base/memory.max")
    else
      used=$(_cg_read "$base/memory.usage_in_bytes")
      limit=$(_cg_read "$base/memory.limit_in_bytes")
    fi
  else
    used=0
    limit="max"
  fi

  anon=$(_cg_stat anon); [ -z "$anon" ] && anon=0
  file=$(_cg_stat file); [ -z "$file" ] && file=0
  slab_rec=$(_cg_stat slab_reclaimable); [ -z "$slab_rec" ] && slab_rec=0
  rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print int(s/1024) "MB"}')
  [ -z "$rss" ] && rss="0MB"
  reclaimable=$(((file + slab_rec) / 1024 / 1024))

  used_mb=$((used / 1024 / 1024))
  if [[ "$limit" =~ ^[0-9]+$ ]] && [ "$limit" -gt 0 ]; then
    limit_mb=$((limit / 1024 / 1024))
    free_mb=$(((limit - used) / 1024 / 1024))
    [ "$free_mb" -lt 0 ] && free_mb=0
    used_pct=$(awk -v u="$used" -v l="$limit" 'BEGIN { if (l>0) printf "%.1f%%", (u/l)*100; else print "-" }')
    print_row "❖" "RAM" "${limit_mb}MB Max" "${used_mb}MB Used" "${free_mb}MB Free"
  else
    print_row "❖" "RAM" "Unknown Max" "${used_mb}MB Used" "cgroup mode"
    used_pct="unknown"
  fi

  print_row "≣" "CACHE" "$((file / 1024 / 1024))MB File" "$((anon / 1024 / 1024))MB Anon" "${rss} RSS"

  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    u1=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
    sleep 0.5
    u2=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
    cpu_used=$(awk -v a="$u1" -v b="$u2" 'BEGIN { v=(b-a)/500000; if(v<0) v=0; printf "%.2f", v }')
  elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
    u1=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
    sleep 0.5
    u2=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
    cpu_used=$(awk -v a="$u1" -v b="$u2" 'BEGIN { v=(b-a)/500000000; if(v<0) v=0; printf "%.2f", v }')
  else
    cpu_used=$(ps -eo %cpu | awk 'NR>1 {sum+=$1} END {printf "%.2f", sum/100}')
  fi
  cpu_pct=$(awk -v v="$cpu_used" 'BEGIN { printf "%.1f%%", (v/2)*100 }')
  print_row "⚙" "CPU" "2.0 vCPU Max" "${cpu_used} vCPU" "(${cpu_pct} Used)"

  disk_total=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
  disk_used=$(df -h / 2>/dev/null | awk 'NR==2 {print $3}')
  disk_free=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}')
  [ -z "$disk_total" ] && disk_total="?"
  [ -z "$disk_used" ] && disk_used="?"
  [ -z "$disk_free" ] && disk_free="?"
  print_row "⛁" "DISK" "${disk_total} Total" "${disk_used} Used" "${disk_free} Free"

  home_items=$(find "$HOME" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$home_items" ] && home_items="0"
  print_row "▣" "HOME" "${home_items} Items" "$USER" "$HOME"

  echo -e "${C_G}------------------------------------------------------------${C_R}"
  echo -e " ${C_W}RAM%${C_R}   ${C_G}::${C_R}  ${C_C}${used_pct}${C_R}"
  echo -e " ${C_W}CACHE${C_R} ${C_G}::${C_R}  ${C_C}${reclaimable}MB likely reclaimable${C_R}"
  echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# ==========================================
# Tailscale commands
# ==========================================

function cc() {
    if pgrep -x "tailscaled" > /dev/null; then
        echo -e "\e[1;33mℹ Tailscale daemon is running.\e[0m"
    else
        echo -e "\e[1;33m⌛ Starting Tailscale in background...\e[0m"
        nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 &
        sleep 3
    fi

    TS_KEY_FILE="$HOME/.ts_auth_key"
    TS_KEY=""

    if [ -f "$TS_KEY_FILE" ]; then
        echo -e "\n\e[1;36m🔑 Previous Key found!\e[0m"
        echo -e "  \e[1;32m1) Use previous Key\e[0m"
        echo -e "  \e[1;33m2) Enter new Key\e[0m"
        read -p "Option [1/2]: " OPTION
        if [ "$OPTION" == "1" ]; then
            TS_KEY=$(cat "$TS_KEY_FILE")
        elif [ "$OPTION" == "2" ]; then
            read -p "New Key: " TS_KEY
            [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
        else
            return 1
        fi
    else
        echo -e "\e[1;36m"
        read -p "Enter Tailscale Auth Key: " TS_KEY
        echo -e "\e[0m"
        [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
    fi

    [ -z "$TS_KEY" ] && return 1
    sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix
    if [ $? -eq 0 ]; then
        echo -e "\n\e[1;32m✔ Success! Phoenix is online.\e[0m\n"
    else
        echo -e "\n\e[1;31m✘ Failed.\e[0m\n"
    fi
}

function cs() {
    sudo tailscale logout 2>/dev/null
    sudo tailscale down 2>/dev/null
    sudo pkill -f tailscaled
    echo -e "\e[1;32m✔ Tailscale stopped.\e[0m\n"
}

# ==========================================
# Clean login screen
# ==========================================

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;33m🔥 Quick Actions:\e[0m"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "cc" "Connect VPN"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "ram" "Detailed RAM Info"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "dcodex" "Show Codex status"
    printf "   \e[1;36m%-10s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View ALL Shortcuts ⚡"
fi
EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc && \
    cat /tmp/setup.sh >> /root/.bashrc && \
    chown devuser:devuser /home/devuser/.bashrc && \
    rm /tmp/setup.sh

# --------------------------------------------------
# Startup script
# --------------------------------------------------
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e
/usr/sbin/sshd
tail -f /dev/null
SH

RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /home/devuser
EXPOSE 22
CMD ["/start.sh"]
