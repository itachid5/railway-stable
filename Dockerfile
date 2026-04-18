FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV TZ="Asia/Dhaka"

ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV NPM_CONFIG_AUDIT=false
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_CACHE=/tmp/.npm-cache

ENV PHOENIX_CPU_SAMPLE_SECONDS=2
ENV PHOENIX_MM_CPU_SAMPLE_SECONDS=2
ENV PHOENIX_CPU_FALLBACK_VCPU=
ENV PHOENIX_CPU_HISTORY_FILE=/var/tmp/phoenix-state/cpu_history.log

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils \
    lsof htop jq speedtest-cli unzip tree python3 python3-pip python3-venv \
    ca-certificates gnupg iproute2 netcat-openbsd \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm i -g @openai/codex --cache /tmp/.npm-cache --no-audit --no-fund \
    && npm cache clean --force \
    && rm -rf /tmp/.npm-cache /root/.npm /root/.cache/npm /root/.cache/node-gyp \
    && apt-get purge -y --auto-remove gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

RUN mkdir -p /var/run/sshd /var/tmp/phoenix-state && chmod 1777 /var/tmp/phoenix-state && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

RUN rm -rf /etc/update-motd.d/* && \
    rm -f /etc/legal /etc/motd && \
    touch /home/devuser/.hushlogin /root/.hushlogin

RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

RUN cat > /tmp/setup.sh <<'EOF'
# ==========================================
# 🚀 SYSTEM ALIASES
# ==========================================

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

alias dsize='du -h --max-depth=1 | sort -hr'
alias chmodx='chmod +x'
alias chownme='sudo chown -R $USER:$USER .'
alias path='echo -e ${PATH//:/\\n}'

alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean && reclaimram'
alias mem='ram'
alias hostmem='free -h'
alias cpu='cpuuse'
alias cpu5='cpuuse 5'
alias df='df -h'
alias top='htop'
alias ports='sudo netstat -tulpn'
alias logs='sudo tail -f /var/log/syslog 2>/dev/null || echo "No /var/log/syslog here."'
alias rst='source ~/.bashrc && echo -e "\e[1;32m✔ Terminal Reloaded!\e[0m"'

alias sysinfo='cat /etc/os-release'
alias cpuinfo='lscpu'
alias myports='ss -tuln'
alias histg='history | grep'

alias myip='echo -e "\n\e[1;36m🌐 IP Details:\e[0m"; curl -s ipinfo.io; echo'
alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple'
alias ping='ping -c 4'
alias ts='sudo tailscale status'

alias pinger='ping -c 4 8.8.8.8'
alias serve='python3 -m http.server 8000'

alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph -n 10'
alias get='wget -c'
alias api='curl -s'
alias weather='curl -s wttr.in/Dhaka?0'

alias mkv='python3 -m venv .venv && echo -e "\e[1;32m✔ .venv created successfully!\e[0m"'
alias onv='source .venv/bin/activate 2>/dev/null || echo -e "\e[1;31m✘ .venv not found! Run mkv first.\e[0m"'
alias offv='deactivate 2>/dev/null || echo -e "\e[1;33mℹ No active virtual environment to deactivate.\e[0m"'

alias apps='echo -e "\n\e[1;36m▶ Codex / Node / Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[c]odex|[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"'
alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"'
alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"'
alias kcodex='sudo pkill -f codex 2>/dev/null; echo -e "\e[1;32m✔ All Codex processes stopped.\e[0m"'

# ==========================================
# 🛠 CUSTOM SHORTCUT MANAGER
# ==========================================

CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts"
if [ -f "$CUSTOM_ALIAS_FILE" ]; then
    source "$CUSTOM_ALIAS_FILE"
fi

function addcmd() {
    echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name (e.g., gohome) : " S_NAME
    [ -z "$S_NAME" ] && { echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; }

    if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' already exists!\e[0m"
        return 1
    fi

    read -p "Command to run (e.g., cd ~)  : " S_CMD
    [ -z "$S_CMD" ] && { echo -e "\e[1;31m✘ Cancelled. Command cannot be empty.\e[0m"; return 1; }

    echo "alias $S_NAME='$S_CMD'" >> "$CUSTOM_ALIAS_FILE"
    eval "alias $S_NAME='$S_CMD'"
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' created!\e[0m\n"
}

function delcmd() {
    echo -e "\n\e[1;31m🗑️ Delete a Custom Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name to delete : " S_NAME
    [ -z "$S_NAME" ] && { echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; }

    if ! grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' not found!\e[0m"
        return 1
    fi

    sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE"
    unalias "$S_NAME" 2>/dev/null
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' deleted!\e[0m\n"
}

# ==========================================
# 🧰 COMMON HELPERS
# ==========================================

function _state_dir() {
    local d="/var/tmp/phoenix-state"
    mkdir -p "$d" 2>/dev/null || {
        d="$HOME/.phoenix-state"
        mkdir -p "$d" 2>/dev/null
    }
    echo "$d"
}

function _cache_get() {
    local name="$1" ttl="${2:-300}" f ts val now
    f="$(_state_dir)/$name"
    [ -f "$f" ] || return 1
    IFS='|' read -r ts val < "$f" || return 1
    now=$(date +%s)
    [ -n "$ts" ] || return 1
    [ $((now - ts)) -le "$ttl" ] || return 1
    echo "$val"
}

function _cache_put() {
    local name="$1" val="$2" f
    f="$(_state_dir)/$name"
    printf '%s|%s\n' "$(date +%s)" "$val" > "$f"
}

function _b2h() {
  awk -v b="${1:-0}" 'BEGIN{
    split("B KB MB GB TB",u," ");
    i=1;
    while (b>=1024 && i<5) { b/=1024; i++ }
    printf "%.1f %s", b, u[i]
  }'
}

function mkcd() { mkdir -p "$1" && cd "$1"; }
function findtext() { grep -rnw . -e "$1"; }

function kport() {
    if [ -z "$1" ]; then
        echo -e "\e[1;31m✘ Usage: kport <port>\e[0m"
        return 1
    fi
    PID=$(sudo lsof -t -i:$1 2>/dev/null)
    if [ -z "$PID" ]; then
        echo -e "\e[1;33mℹ Port $1 is free\e[0m"
    else
        sudo kill -9 $PID
        echo -e "\e[1;32m✔ Killed process on port $1\e[0m"
    fi
}

function ex() {
    if [ -z "$1" ]; then
        echo -e "\e[1;31m✘ Usage: ex <filename>\e[0m"
        return 1
    fi
    if [ -f "$1" ]; then
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
# 🧠 ENV / VENV / CODEX / INSTALLERS
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
        echo -e "\e[1;31m✘ No virtual environment found!\e[0m"
        echo -e "\e[1;33mℹ Run 'mkv' to create one.\e[0m"
    fi
}

function dcodex() {
    echo -e "\n\e[1;36m🤖 Codex Status\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    if command -v codex >/dev/null 2>&1; then
        echo -e "\e[1;32m✔ Codex is already installed in this image.\e[0m"
        echo -e "\e[1;36mCodex Version:\e[0m $(codex --version 2>/dev/null || echo installed)"
        echo -e "\e[1;36mNode Version:\e[0m $(node -v 2>/dev/null || echo missing)"
        echo -e "\e[1;36mNPM Version:\e[0m $(npm -v 2>/dev/null || echo missing)"
        echo -e "\e[1;33mℹ Run 'codex' manually when needed.\e[0m"
    else
        echo -e "\e[1;31m✘ Codex not found. Rebuild image.\e[0m"
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

    echo -e "\e[1;33m⚠ Missing packages detected. Runtime install can increase file cache.\e[0m"
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
    echo -e "\e[1;33m⚠ Runtime install can increase file cache.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends golang
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Go installed successfully!\e[0m"
    go version
}

function djava() {
    echo -e "\n\e[1;36m☕ Installing Java 17 LTS...\e[0m"
    echo -e "\e[1;33m⚠ Runtime install can increase file cache.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Java installed successfully!\e[0m"
    java -version
}

# ==========================================
# 🧠 MEMORY / RAM
# ==========================================

function _mem_mode() {
  if [ -f /sys/fs/cgroup/memory.current ]; then
    echo "v2"
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
    echo "v1"
  else
    echo ""
  fi
}

function _cg_base() {
  if [ -f /sys/fs/cgroup/memory.current ]; then
    echo "/sys/fs/cgroup"
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
    echo "/sys/fs/cgroup/memory"
  else
    echo ""
  fi
}

function _cg_read() {
  [ -f "$1" ] && cat "$1" 2>/dev/null || echo 0
}

function _cg_stat() {
  local key="$1" base="$(_cg_base)" mode="$(_mem_mode)" alt=""
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
    printf "  %-7s │ %-8.8s │ %-6s │ %-10s │ %s\n" "$pid" "$user" "${mem}%" "$(_b2h "$((rss * 1024))")" "$comm"
  done
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function ramwhy() {
  local base used limit anon file shmem slab pgt kstack sock rss codex_proc node_proc py_proc
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
  pgt=${_CG_PGT:-$(_cg_stat pagetables)}; [ -z "$pgt" ] && pgt=0
  kstack=${_CG_KSTACK:-$(_cg_stat kernel_stack)}; [ -z "$kstack" ] && kstack=0
  sock=${_CG_SOCK:-$(_cg_stat sock)}; [ -z "$sock" ] && sock=0
  rss=$(ps -eo rss= 2>/dev/null | awk '{s+=$1} END {print s*1024}')
  [ -z "$rss" ] && rss=0

  codex_proc=$(pgrep -af '(^|/)(codex)( |$)|@openai/codex' 2>/dev/null | head -n 3)
  node_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[n]ode|[n]pm' | head -n 5)
  py_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[p]ython' | head -n 5)

  echo -e "\n\e[1;35m🔎 RAM Diagnosis\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

  if [ "$file" -gt "$anon" ] && [ "$file" -gt $((150*1024*1024)) ]; then
    echo -e "\e[1;33mMain Cause:\e[0m File/Page cache is dominating memory."
    echo -e "This usually happens after installs, archive extraction, or heavy file reads."
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

  echo -e "\n\e[1;36mRun these:\e[0m \e[1;32mramtop\e[0m | \e[1;32mramwhy\e[0m | \e[1;32mcachefiles\e[0m | \e[1;32mreclaimram\e[0m\n"
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
    echo -e "\e[1;33mℹ Cache files removed, but kernel page cache drop is not allowed here.\e[0m"
    echo -e "\e[1;33mℹ If file cache stays high, restart/redeploy the container.\e[0m"
  fi

  ram
}

# ==========================================
# ⚙ CPU
# ==========================================

function _cpu_mode() {
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    echo "v2"
  elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ] || [ -f /sys/fs/cgroup/cpu/cpu.stat ]; then
    echo "v1"
  else
    echo ""
  fi
}

function _cpu_limit() {
  local quota period
  if [ -f /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max
    if [ "$quota" != "max" ] && [ -n "$period" ] && [ "$period" -gt 0 ] 2>/dev/null; then
      awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.2f\n", q/p }'
      return
    fi
  fi

  if [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null)
    period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null)
    if [ -n "$quota" ] && [ "$quota" -gt 0 ] 2>/dev/null && [ -n "$period" ] && [ "$period" -gt 0 ] 2>/dev/null; then
      awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.2f\n", q/p }'
      return
    fi
  fi

  if [ -n "$PHOENIX_CPU_FALLBACK_VCPU" ] && awk -v v="$PHOENIX_CPU_FALLBACK_VCPU" 'BEGIN { exit !(v>0) }'; then
    printf "%.2f\n" "$PHOENIX_CPU_FALLBACK_VCPU"
    return
  fi

  echo "0"
}

function _cpu_limit_label() {
  local l="$(_cpu_limit)"
  if awk -v v="$l" 'BEGIN { exit !(v>0) }'; then
    printf "%s vCPU limit" "$l"
  else
    printf "shared/auto"
  fi
}

function _cpu_usage_usec() {
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    awk '/^usage_usec / {print $2; exit}' /sys/fs/cgroup/cpu.stat 2>/dev/null
    return
  fi
  if [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
    awk '{printf "%.0f\n", $1/1000}' /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null
    return
  fi
  echo 0
}

function _cpu_throttled_usec() {
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    awk '/^throttled_usec / {print $2; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu.stat 2>/dev/null
    return
  fi
  if [ -f /sys/fs/cgroup/cpu/cpu.stat ]; then
    awk '/^throttled_time / {printf "%.0f\n", $2/1000; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null
    return
  fi
  echo 0
}

function _cpu_nr_throttled() {
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    awk '/^nr_throttled / {print $2; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu.stat 2>/dev/null
    return
  fi
  if [ -f /sys/fs/cgroup/cpu/cpu.stat ]; then
    awk '/^nr_throttled / {print $2; found=1} END {if(!found) print 0}' /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null
    return
  fi
  echo 0
}

function _cpu_pressure_avg() {
  local kind="${1:-some}" window="avg${2:-10}"
  [ ! -f /sys/fs/cgroup/cpu.pressure ] && { echo "0.00"; return; }
  awk -v k="$kind" -v w="$window" '$1==k { for(i=2;i<=NF;i++){ split($i,a,"="); if(a[1]==w){ print a[2]; found=1; exit } } } END { if(!found) print "0.00" }' /sys/fs/cgroup/cpu.pressure 2>/dev/null
}

function _cpu_history_file() {
  echo "${PHOENIX_CPU_HISTORY_FILE:-$(_state_dir)/cpu_history.log}"
}

function _cpu_record_history() {
  local used="$1" limit="$2" pct="$3" file tmp
  file="$(_cpu_history_file)"
  tmp="${file}.tmp"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  printf '%s|%s|%s|%s\n' "$(date +%s)" "$used" "$limit" "$pct" >> "$file"
  tail -n 180 "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
}

function _cpu_avg_history() {
  local window="${1:-30}" file now
  file="$(_cpu_history_file)"
  [ ! -f "$file" ] && return 1
  now=$(date +%s)
  awk -F'|' -v cutoff="$((now - window))" '$1>=cutoff {sum+=$2; n++} END { if(n>0) printf "%.3f\n", sum/n; else exit 1 }' "$file"
}

function _cpu_measure() {
  local secs="${1:-2}" u1 u2 t1 t2 wall thr1 thr2 n1 n2 used limit pct thr_pct psi_some psi_full
  u1=$(_cpu_usage_usec)
  thr1=$(_cpu_throttled_usec)
  n1=$(_cpu_nr_throttled)
  t1=$(date +%s%N)
  sleep "$secs"
  t2=$(date +%s%N)
  u2=$(_cpu_usage_usec)
  thr2=$(_cpu_throttled_usec)
  n2=$(_cpu_nr_throttled)
  wall=$(( (t2 - t1) / 1000 ))
  [ "$wall" -le 0 ] && wall=1

  used=$(awk -v du="$((u2-u1))" -v dw="$wall" 'BEGIN{ v=du/dw; if(v<0) v=0; printf "%.3f", v }')
  limit=$(_cpu_limit)
  pct=$(awk -v u="$used" -v l="$limit" 'BEGIN{ if(l>0) printf "%.1f", (u/l)*100; else print "-" }')
  thr_pct=$(awk -v dt="$((thr2-thr1))" -v dw="$wall" 'BEGIN{ if(dw>0){ p=(dt/dw)*100; if(p<0)p=0; printf "%.1f", p } else print "0.0" }')
  psi_some=$(_cpu_pressure_avg some 10)
  psi_full=$(_cpu_pressure_avg full 10)

  _cpu_record_history "$used" "$limit" "$pct"
  echo "$used|$limit|$pct|$((thr2-thr1))|$thr_pct|$((n2-n1))|$psi_some|$psi_full|$secs"
}

function cputop() {
  echo -e "\n\e[1;36m📈 Top Processes by CPU\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-7s │ %-8s │ %-6s │ %-10s │ %-10s │ %s\n" "PID" "USER" "CPU%" "RSS" "ELAPSED" "COMMAND"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  ps -eo pid=,user=,%cpu=,etime=,rss=,comm= --sort=-%cpu | head -n 15 | while read -r pid user cpu etime rss comm; do
    printf "  %-7s │ %-8.8s │ %-6s │ %-10s │ %-10s │ %s\n" "$pid" "$user" "${cpu}%" "$(_b2h "$((rss * 1024))")" "$etime" "$comm"
  done
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function cpuavg() {
  local win="${1:-30}" avg limit pct label
  avg=$(_cpu_avg_history "$win" 2>/dev/null || true)
  if [ -z "$avg" ]; then
    echo -e "\n\e[1;33mℹ No local CPU history yet. Run \e[1;36mcpu\e[0m or \e[1;36mcpulive\e[0m first.\n"
    return 1
  fi

  limit=$(_cpu_limit)
  pct=$(awk -v u="$avg" -v l="$limit" 'BEGIN{ if(l>0) printf "%.1f", (u/l)*100; else print "-" }')
  label="$(_cpu_limit_label)"

  echo -e "\n\e[1;36m🧠 Local CPU Average\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-20s : %s sec\n" "Window" "$win"
  printf "  %-20s : %s vCPU\n" "Average Used" "$avg"
  printf "  %-20s : %s\n" "Limit" "$label"
  [ "$pct" != "-" ] && printf "  %-20s : %s%%\n" "Percent of Limit" "$pct"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function cpuuse() {
  local secs="${1:-${PHOENIX_CPU_SAMPLE_SECONDS:-2}}" data used limit pct thr_usec thr_pct thr_n psi_some psi_full sample avg30 limit_label
  data="$(_cpu_measure "$secs")"
  IFS='|' read -r used limit pct thr_usec thr_pct thr_n psi_some psi_full sample <<< "$data"
  avg30=$(_cpu_avg_history 30 2>/dev/null || true)
  limit_label="$(_cpu_limit_label)"

  echo -e "\n\e[1;36m⚙ CPU (cgroup-based)\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-20s : %s sec\n" "Sample Window" "$sample"
  printf "  %-20s : %s vCPU\n" "Used" "$used"
  printf "  %-20s : %s\n" "Limit" "$limit_label"
  if [ "$pct" != "-" ]; then
    printf "  %-20s : %s%%\n" "Percent of Limit" "$pct"
  else
    printf "  %-20s : %s\n" "Percent of Limit" "shared / not fixed"
  fi
  [ -n "$avg30" ] && printf "  %-20s : %s vCPU\n" "Local Avg (30s)" "$avg30"
  printf "  %-20s : %s\n" "Throttle Events" "$thr_n"
  printf "  %-20s : %s%%\n" "Throttle Time" "$thr_pct"
  printf "  %-20s : %s%%\n" "CPU PSI some avg10" "$psi_some"
  printf "  %-20s : %s%%\n" "CPU PSI full avg10" "$psi_full"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  echo -e "\e[1;33mTip:\e[0m For a steadier number, run \e[1;36mcpu 5\e[0m or \e[1;36mcpulive 2\e[0m.\n"
}

function cpuwhy() {
  local secs="${1:-3}" data used limit pct thr_usec thr_pct thr_n psi_some psi_full sample avg30
  data="$(_cpu_measure "$secs")"
  IFS='|' read -r used limit pct thr_usec thr_pct thr_n psi_some psi_full sample <<< "$data"
  avg30=$(_cpu_avg_history 30 2>/dev/null || true)

  echo -e "\n\e[1;35m🔎 CPU Diagnosis\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

  if [ "$thr_n" -gt 0 ] || awk -v t="$thr_pct" 'BEGIN { exit !(t>0.1) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m CPU throttling happened during the sample."
    echo -e "The workload wanted more CPU time than the cgroup scheduling allowed."
  elif [ "$pct" != "-" ] && awk -v p="$pct" 'BEGIN { exit !(p>=70) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m Real CPU load is high."
  elif awk -v s="$psi_some" 'BEGIN { exit !(s>=5.0) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m CPU pressure is noticeable."
    echo -e "Tasks are waiting to run."
  elif [ -n "$avg30" ] && awk -v a="$avg30" -v u="$used" 'BEGIN { exit !(a>0.05 && u<(a/2)) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m Current instant is calmer than recent history."
  else
    echo -e "\e[1;33mMain Cause:\e[0m Current CPU usage looks low or moderate."
  fi

  echo -e "\n\e[1;36mCurrent Sample:\e[0m"
  echo -e "  Used           : ${used} vCPU"
  echo -e "  Sample Window  : ${sample}s"
  if [ "$pct" != "-" ]; then
    echo -e "  Percent Limit  : ${pct}%"
  else
    echo -e "  Percent Limit  : shared / not fixed"
  fi
  echo -e "  Throttle Events: ${thr_n}"
  echo -e "  Throttle Time  : ${thr_pct}%"
  echo -e "  PSI some avg10 : ${psi_some}%"
  echo -e "  PSI full avg10 : ${psi_full}%"
  [ -n "$avg30" ] && echo -e "  Local Avg 30s  : ${avg30} vCPU"

  echo -e "\n\e[1;32mWhat to do now:\e[0m"
  echo -e "  1) Run \e[1;36mcpu 5\e[0m"
  echo -e "  2) Run \e[1;36mcputop\e[0m"
  echo -e "  3) Run \e[1;36mcpulive 2\e[0m"
  echo -e "  4) Run \e[1;36mcginfo\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function cpulive() {
  local secs="${1:-2}"
  echo -e "\e[1;36mLive CPU monitor. Press Ctrl+C to stop.\e[0m"
  sleep 1
  while true; do
    clear
    cpuuse "$secs"
    cputop
  done
}

function cginfo() {
  echo -e "\n\e[1;36m🧩 Raw cgroup info\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-22s : %s\n" "CPU mode" "$(_cpu_mode)"
  printf "  %-22s : %s\n" "CPU limit label" "$(_cpu_limit_label)"
  printf "  %-22s : %s\n" "Fallback vCPU" "${PHOENIX_CPU_FALLBACK_VCPU:-unset}"

  [ -f /sys/fs/cgroup/cpu.max ] && printf "  %-22s : %s\n" "cpu.max" "$(cat /sys/fs/cgroup/cpu.max 2>/dev/null)"
  [ -f /sys/fs/cgroup/cpu.weight ] && printf "  %-22s : %s\n" "cpu.weight" "$(cat /sys/fs/cgroup/cpu.weight 2>/dev/null)"
  [ -f /sys/fs/cgroup/cpuset.cpus.effective ] && printf "  %-22s : %s\n" "cpuset effective" "$(cat /sys/fs/cgroup/cpuset.cpus.effective 2>/dev/null)"

  if [ -f /sys/fs/cgroup/cpu.pressure ]; then
    echo -e "  cpu.pressure            :"
    sed 's/^/    /' /sys/fs/cgroup/cpu.pressure 2>/dev/null
  fi
  if [ -f /sys/fs/cgroup/cpu.stat ]; then
    echo -e "  cpu.stat                :"
    sed 's/^/    /' /sys/fs/cgroup/cpu.stat 2>/dev/null
  fi
  if [ -f /sys/fs/cgroup/memory.current ]; then
    printf "  %-22s : %s\n" "memory.current" "$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"
  fi
  if [ -f /sys/fs/cgroup/memory.max ]; then
    printf "  %-22s : %s\n" "memory.max" "$(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
  fi

  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# 💾 DISK / C DISK
# ==========================================

function _cdisk_scan_bytes() {
    sudo du -x -s --block-size=1 / --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run 2>/dev/null | awk '{print $1}'
}

function _cdisk_bytes() {
    local mode="${1:-}" ttl="${2:-900}" val
    if [ "$mode" != "refresh" ]; then
        val=$(_cache_get cdisk_bytes "$ttl" 2>/dev/null || true)
        [ -n "$val" ] && { echo "$val"; return; }
    fi
    val=$(_cdisk_scan_bytes)
    [ -z "$val" ] && val=0
    _cache_put cdisk_bytes "$val"
    echo "$val"
}

function cdisk() {
    local mode="${1:-}" ttl="${2:-900}" bytes
    echo -e "\n\e[1;36m💾 C DISK (Container Used Space)\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    if [ "$mode" = "refresh" ]; then
        echo -e "\e[1;33m⌛ Refreshing full container scan...\e[0m"
    fi
    bytes=$(_cdisk_bytes "$mode" "$ttl")
    printf "  %-22s : %s\n" "Container Used" "$(_b2h "$bytes")"
    printf "  %-22s : %s\n" "Scope" "All visible files inside container"
    printf "  %-22s : %s\n" "Excludes" "/proc /sys /dev /run"
    printf "  %-22s : %s\n" "Refresh" "cdisk refresh"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function cspace() {
    local path="${1:-/}"
    echo -e "\n\e[1;36m📦 Biggest Directories under ${path}\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    sudo du -x -h --max-depth=1 "$path" 2>/dev/null | sort -hr | head -n 25
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# 🌐 NETWORK
# ==========================================

function _net_now() {
    awk 'NR>2 {gsub(":","",$1); if($1!="lo"){rx+=$2; tx+=$10}} END{print (rx+0) "|" (tx+0)}' /proc/net/dev 2>/dev/null
}

function _net_boot_id() {
    cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo "unknown"
}

function _net_state_file() {
    echo "$(_state_dir)/net_today.state"
}

function _net_today_values() {
    local f today boot current rx tx s_date s_boot base_rx base_tx
    f="$(_net_state_file)"
    today=$(date +%F)
    boot=$(_net_boot_id)
    current=$(_net_now)
    rx=${current%|*}
    tx=${current#*|}

    if [ -f "$f" ]; then
        IFS='|' read -r s_date s_boot base_rx base_tx < "$f"
    fi

    if [ "$s_date" != "$today" ] || [ "$s_boot" != "$boot" ] || [ -z "$base_rx" ] || [ -z "$base_tx" ]; then
        printf '%s|%s|%s|%s\n' "$today" "$boot" "$rx" "$tx" > "$f"
        base_rx="$rx"
        base_tx="$tx"
    fi

    echo "$base_rx|$base_tx|$rx|$tx"
}

function _net_rate_sample() {
    local secs="${1:-1}" a b rx1 tx1 rx2 tx2
    a=$(_net_now)
    rx1=${a%|*}; tx1=${a#*|}
    sleep "$secs"
    b=$(_net_now)
    rx2=${b%|*}; tx2=${b#*|}
    echo "$(( (rx2-rx1) / secs ))|$(( (tx2-tx1) / secs ))"
}

function net() {
    local vals base_rx base_tx cur_rx cur_tx today_rx today_tx total today_total rate rxps txps
    vals=$(_net_today_values)
    IFS='|' read -r base_rx base_tx cur_rx cur_tx <<< "$vals"
    today_rx=$((cur_rx - base_rx)); [ "$today_rx" -lt 0 ] && today_rx=0
    today_tx=$((cur_tx - base_tx)); [ "$today_tx" -lt 0 ] && today_tx=0
    total=$((cur_rx + cur_tx))
    today_total=$((today_rx + today_tx))
    rate=$(_net_rate_sample 1)
    rxps=${rate%|*}; txps=${rate#*|}

    echo -e "\n\e[1;36m🌐 Network Overview (Container Local)\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    printf "  %-22s : %s\n" "Today In (RX)" "$(_b2h "$today_rx")"
    printf "  %-22s : %s\n" "Today Out (TX)" "$(_b2h "$today_tx")"
    printf "  %-22s : %s\n" "Today Total" "$(_b2h "$today_total")"
    printf "  %-22s : %s\n" "Since Boot In (RX)" "$(_b2h "$cur_rx")"
    printf "  %-22s : %s\n" "Since Boot Out (TX)" "$(_b2h "$cur_tx")"
    printf "  %-22s : %s\n" "Since Boot Total" "$(_b2h "$total")"
    printf "  %-22s : %s\n" "Live RX rate" "$(_b2h "$rxps")/s"
    printf "  %-22s : %s\n" "Live TX rate" "$(_b2h "$txps")/s"
    printf "  %-22s : %s\n" "Note" "Today = since today's first local sample / same boot"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function netlive() {
    local secs="${1:-1}" prev cur rx1 tx1 rx2 tx2 rxps txps
    echo -e "\e[1;36mLive network monitor. Press Ctrl+C to stop.\e[0m"
    prev=$(_net_now)
    while true; do
        sleep "$secs"
        cur=$(_net_now)
        rx1=${prev%|*}; tx1=${prev#*|}
        rx2=${cur%|*};  tx2=${cur#*|}
        rxps=$(( (rx2-rx1) / secs )); [ "$rxps" -lt 0 ] && rxps=0
        txps=$(( (tx2-tx1) / secs )); [ "$txps" -lt 0 ] && txps=0
        clear
        echo -e "\n\e[1;36m🌐 Live Network\e[0m"
        echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
        printf "  %-20s : %s\n" "Interval" "${secs}s"
        printf "  %-20s : %s\n" "RX" "$(_b2h "$rxps")/s"
        printf "  %-20s : %s\n" "TX" "$(_b2h "$txps")/s"
        echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
        prev=$cur
    done
}

function nettop() {
    echo -e "\n\e[1;36m🌍 Top Remote Peers / Connections\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    ss -Htun 2>/dev/null | awk '
    {
        remote=$5
        gsub(/^\[/, "", remote)
        sub(/\]:[0-9]+$/, "", remote)
        sub(/:[0-9]+$/, "", remote)
        if(remote!="" && remote!="*" && remote!="0.0.0.0" && remote!="::") cnt[remote]++
    }
    END{
        for(i in cnt) print cnt[i], i
    }' | sort -nr | head -n 20
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function netconn() {
    echo -e "\n\e[1;36m🔌 Connection Summary\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    ss -tan 2>/dev/null | awk 'NR>1 {state[$1]++} END{for(i in state) printf "  %-15s : %s\n", i, state[i]}' | sort
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# 📀 IO / FD / PROCESS SUMMARY
# ==========================================

function _io_now() {
    local r=0 w=0
    if [ -f /sys/fs/cgroup/io.stat ]; then
        awk '{
          for(i=1;i<=NF;i++){
            if($i ~ /^rbytes=/){split($i,a,"="); r+=a[2]}
            else if($i ~ /^wbytes=/){split($i,a,"="); w+=a[2]}
          }
        } END{print (r+0) "|" (w+0)}' /sys/fs/cgroup/io.stat 2>/dev/null
        return
    fi
    if [ -f /sys/fs/cgroup/blkio/blkio.throttle.io_service_bytes ]; then
        awk '/Read/ {r+=$3} /Write/ {w+=$3} END{print (r+0) "|" (w+0)}' /sys/fs/cgroup/blkio/blkio.throttle.io_service_bytes 2>/dev/null
        return
    fi
    echo "0|0"
}

function io() {
    local secs="${1:-2}" a b r1 w1 r2 w2 dr dw
    a=$(_io_now)
    r1=${a%|*}; w1=${a#*|}
    sleep "$secs"
    b=$(_io_now)
    r2=${b%|*}; w2=${b#*|}
    dr=$((r2-r1)); [ "$dr" -lt 0 ] && dr=0
    dw=$((w2-w1)); [ "$dw" -lt 0 ] && dw=0

    echo -e "\n\e[1;36m📀 IO (cgroup-based)\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    printf "  %-22s : %s\n" "Read Total" "$(_b2h "$r2")"
    printf "  %-22s : %s\n" "Write Total" "$(_b2h "$w2")"
    printf "  %-22s : %s\n" "Read Rate" "$(_b2h "$((dr / secs))")/s"
    printf "  %-22s : %s\n" "Write Rate" "$(_b2h "$((dw / secs))")/s"
    printf "  %-22s : %s\n" "Window" "${secs}s"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function iotop() {
    echo -e "\n\e[1;36m📚 Top Processes by Accumulated IO\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    sudo bash -c '
    for d in /proc/[0-9]*; do
        pid=${d##*/}
        [ -r "$d/io" ] || continue
        rb=$(awk "/^read_bytes:/ {print \$2}" "$d/io" 2>/dev/null)
        wb=$(awk "/^write_bytes:/ {print \$2}" "$d/io" 2>/dev/null)
        [ -z "$rb" ] && rb=0
        [ -z "$wb" ] && wb=0
        total=$((rb + wb))
        [ "$total" -le 0 ] && continue
        user=$(stat -c %U "$d" 2>/dev/null)
        comm=$(cat "$d/comm" 2>/dev/null)
        printf "%s|%s|%s|%s|%s|%s\n" "$total" "$pid" "$user" "$rb" "$wb" "$comm"
    done
    ' 2>/dev/null | sort -t'|' -nrk1 | head -n 15 | while IFS='|' read -r total pid user rb wb comm; do
        printf "  %-7s │ %-8.8s │ %-10s │ %-10s │ %s\n" "$pid" "$user" "$(_b2h "$rb")" "$(_b2h "$wb")" "$comm"
    done
    echo -e "\n  Columns: PID │ USER │ READ │ WRITE │ COMMAND"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function fdtop() {
    echo -e "\n\e[1;36m🗂 Top Processes by Open File Descriptors\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    sudo bash -c '
    for d in /proc/[0-9]*; do
        pid=${d##*/}
        [ -d "$d/fd" ] || continue
        cnt=$(find "$d/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        [ "$cnt" -le 0 ] && continue
        user=$(stat -c %U "$d" 2>/dev/null)
        comm=$(cat "$d/comm" 2>/dev/null)
        printf "%s|%s|%s|%s\n" "$cnt" "$pid" "$user" "$comm"
    done
    ' 2>/dev/null | sort -t'|' -nrk1 | head -n 15 | while IFS='|' read -r cnt pid user comm; do
        printf "  %-7s │ %-7s │ %-8.8s │ %s\n" "$cnt" "$pid" "$user" "$comm"
    done
    echo -e "\n  Columns: FDs │ PID │ USER │ COMMAND"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function psummary() {
    local pcount tcount zcount ecount l1 l5 l15 up
    pcount=$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')
    tcount=$(ps -eLo pid --no-headers 2>/dev/null | wc -l | tr -d ' ')
    zcount=$(ps -eo stat= 2>/dev/null | awk '/^Z/ {c++} END{print c+0}')
    ecount=$(ss -Htan state established 2>/dev/null | wc -l | tr -d ' ')
    read -r l1 l5 l15 _ < /proc/loadavg
    up=$(uptime -p 2>/dev/null)

    echo -e "\n\e[1;36m🧾 Process Summary\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
    printf "  %-22s : %s\n" "Processes" "$pcount"
    printf "  %-22s : %s\n" "Threads" "$tcount"
    printf "  %-22s : %s\n" "Zombies" "$zcount"
    printf "  %-22s : %s\n" "Established TCP" "$ecount"
    printf "  %-22s : %s %s %s\n" "Load Avg" "$l1" "$l5" "$l15"
    printf "  %-22s : %s\n" "Uptime" "$up"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# 📊 BIG DASHBOARD
# ==========================================

function mm() {
  local base used limit used_mb limit_mb free_mb used_pct
  local anon file rss reclaimable slab_rec
  local cpu_data cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample avg30
  local disk_total disk_used disk_free
  local cdisk_bytes cdisk_txt
  local net_vals base_rx base_tx cur_rx cur_tx today_rx today_tx today_total
  local home_items
  local C_C="\e[36m" C_G="\e[90m" C_W="\e[1;37m" C_R="\e[0m"

  echo -e "\n${C_W}▶ SYSTEM MONITOR (Container Accurate)${C_R}\n${C_G}--------------------------------------------------------------------------${C_R}"

  print_row() {
    echo -e " $1  ${C_W}$(printf "%-7s" "$2")${C_R} ${C_G}::${C_R}  ${C_C}$(printf "%-18s" "$3")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-18s" "$4")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-18s" "$5")${C_R}"
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

  cpu_data="$(_cpu_measure "${PHOENIX_MM_CPU_SAMPLE_SECONDS:-2}")"
  IFS='|' read -r cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample <<< "$cpu_data"
  avg30=$(_cpu_avg_history 30 2>/dev/null || true)
  if awk -v v="$cpu_limit" 'BEGIN { exit !(v>0) }'; then
    print_row "⚙" "CPU" "${cpu_limit} vCPU Max" "${cpu_used} vCPU ${cpu_sample}s" "${cpu_pct}% Limit"
  else
    print_row "⚙" "CPU" "shared/auto" "${cpu_used} vCPU ${cpu_sample}s" "no fixed cap"
  fi
  [ -z "$avg30" ] && avg30="$cpu_used"
  print_row "⌁" "CPU+" "${avg30} vCPU 30s" "${cpu_thr_pct}% Throttle" "${cpu_psi_some}% PSI10"

  disk_total=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
  disk_used=$(df -h / 2>/dev/null | awk 'NR==2 {print $3}')
  disk_free=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}')
  [ -z "$disk_total" ] && disk_total="?"
  [ -z "$disk_used" ] && disk_used="?"
  [ -z "$disk_free" ] && disk_free="?"
  print_row "⛁" "DISK" "${disk_total} Total" "${disk_used} Used" "${disk_free} Free"

  cdisk_bytes=$(_cdisk_bytes "" 900)
  cdisk_txt="$(_b2h "$cdisk_bytes")"
  print_row "▣" "C DISK" "${cdisk_txt}" "visible container data" "refresh: cdisk refresh"

  net_vals=$(_net_today_values)
  IFS='|' read -r base_rx base_tx cur_rx cur_tx <<< "$net_vals"
  today_rx=$((cur_rx - base_rx)); [ "$today_rx" -lt 0 ] && today_rx=0
  today_tx=$((cur_tx - base_tx)); [ "$today_tx" -lt 0 ] && today_tx=0
  today_total=$((today_rx + today_tx))
  print_row "🌐" "NET" "$(_b2h "$today_rx") In Today" "$(_b2h "$today_tx") Out Today" "$(_b2h "$today_total") Total"

  home_items=$(find "$HOME" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$home_items" ] && home_items="0"
  print_row "🏠" "HOME" "${home_items} Items" "$USER" "$HOME"

  echo -e "${C_G}--------------------------------------------------------------------------${C_R}"
  echo -e " ${C_W}RAM%${C_R}    ${C_G}::${C_R}  ${C_C}${used_pct}${C_R}"
  echo -e " ${C_W}CACHE${C_R}   ${C_G}::${C_R}  ${C_C}${reclaimable}MB likely reclaimable${C_R}"
  echo -e " ${C_W}CPU NOW${C_R} ${C_G}::${C_R}  ${C_C}${cpu_used} vCPU (${cpu_sample}s avg)${C_R}"
  echo -e "${C_G}--------------------------------------------------------------------------${C_R}\n"
}

# ==========================================
# 🧪 FULL DIAGNOSTICS
# ==========================================

function diag() {
    mm
    cpuwhy 3
    ramwhy
    net
    io 1
    psummary
}

# ==========================================
# 🔌 TAILSCALE
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
        if [ "$OPTION" = "1" ]; then
            TS_KEY=$(cat "$TS_KEY_FILE")
        elif [ "$OPTION" = "2" ]; then
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
# 📚 COMMAND MENU
# ==========================================

function pcmd() {
    printf "   \e[1;32m%-16s\e[0m : %s\n" "$1" "$2"
}

function cmds() {
    echo -e "\n\e[1;37m⚡ ALL MAGICAL SHORTCUTS ⚡\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

    echo -e "\e[1;33m📁 Navigation & Files\e[0m"
    pcmd "c" "Clear screen"
    pcmd ".. / ..." "Go back folders"
    pcmd "ll / la" "List files"
    pcmd "sz" "Show size in current directory"
    pcmd "md" "Create directory"
    pcmd "mkcd <dir>" "Create and enter directory"
    pcmd "tree" "Visual tree"
    pcmd "dsize" "Sub-folder sizes"
    pcmd "chownme" "Take ownership"
    pcmd "chmodx" "Make file executable"
    pcmd "ex <file>" "Extract archive"
    pcmd "findbig" "Files larger than 50MB"
    pcmd "findtext <txt>" "Search text in files"
    pcmd "cspace [path]" "Biggest directories"

    echo -e "\n\e[1;33m💻 System / Monitor\e[0m"
    pcmd "mm" "Main dashboard"
    pcmd "diag" "Full diagnostics"
    pcmd "up" "Update & upgrade packages"
    pcmd "clean" "Autoremove + clean + reclaimram"
    pcmd "mem / ram" "Container RAM summary"
    pcmd "hostmem" "Raw free -h"
    pcmd "ramtop" "Top processes by RSS"
    pcmd "ramwhy" "Explain RAM usage"
    pcmd "cachefiles" "Show cache directories"
    pcmd "reclaimram" "Remove cache files"
    pcmd "cpu" "CPU usage (2s avg)"
    pcmd "cpu5" "CPU usage (5s avg)"
    pcmd "cpuwhy [s]" "Explain CPU spikes"
    pcmd "cpuavg [s]" "Average saved CPU history"
    pcmd "cputop" "Top CPU processes"
    pcmd "cpulive [s]" "Live CPU view"
    pcmd "cginfo" "Raw cgroup info"

    echo -e "\n\e[1;33m💾 Disk / IO / Network\e[0m"
    pcmd "df" "Filesystem usage"
    pcmd "cdisk [refresh]" "Visible full container used size"
    pcmd "cspace [path]" "Biggest directories"
    pcmd "io [s]" "Container IO totals and rates"
    pcmd "iotop" "Top processes by accumulated IO"
    pcmd "fdtop" "Top processes by open files"
    pcmd "net" "Today and boot network totals"
    pcmd "netlive [s]" "Live network speeds"
    pcmd "nettop" "Top remote peers"
    pcmd "netconn" "Connection state summary"
    pcmd "psummary" "Processes / threads / zombies"

    echo -e "\n\e[1;33m🎯 App Management\e[0m"
    pcmd "apps" "List Codex/Node/Python apps"
    pcmd "kn" "Kill all Node apps"
    pcmd "kp" "Kill all Python apps"
    pcmd "kcodex" "Kill all Codex processes"
    pcmd "kport <no>" "Kill app on a port"

    echo -e "\n\e[1;33m🌐 Network & VPN\e[0m"
    pcmd "cc" "Connect Tailscale"
    pcmd "cs" "Disconnect Tailscale"
    pcmd "ts" "Tailscale status"
    pcmd "myip" "Public IP info"
    pcmd "pinger" "Quick connectivity test"
    pcmd "speed" "Speed test"
    pcmd "serve" "Serve current directory on :8000"

    echo -e "\n\e[1;33m🛠 Dev & Tools\e[0m"
    pcmd "weather" "Weather in Dhaka"
    pcmd "gs / ga / gc" "Git shortcuts"
    pcmd "addcmd" "Create personal shortcut"
    pcmd "delcmd" "Delete personal shortcut"
    pcmd "mkv" "Create .venv"
    pcmd "onv / offv" "Activate / deactivate .venv"
    pcmd "sv" "Smart activate venv"
    pcmd "dcodex" "Show Codex status"
    pcmd "dpy" "Check Python/Pip/Venv"
    pcmd "dgo" "Install Go at runtime"
    pcmd "djava" "Install Java at runtime"

    echo -e "\n\e[1;35m👤 My Personal Shortcuts\e[0m"
    if [ -f "$CUSTOM_ALIAS_FILE" ] && [ -s "$CUSTOM_ALIAS_FILE" ]; then
        cat "$CUSTOM_ALIAS_FILE" | sed "s/alias //g" | sed "s/='/|/g" | sed "s/'//g" | while IFS='|' read -r name cmd; do
            pcmd "$name" "$cmd"
        done
    else
        echo -e "   \e[90mNo personal shortcuts yet. Type 'addcmd' to create one.\e[0m"
    fi

    echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ==========================================
# 🎉 CLEAN LOGIN SCREEN
# ==========================================

function custom_motd() {
    local OS_VERSION KERNEL_VERSION ARCH CPU_MODEL LAST_LOGIN_FILE LAST_LOGIN_DATA LAST_LOGIN_TIME LAST_LOGIN_IP CURRENT_IP UPTIME_SEC MY_UPTIME d h m
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

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;33m🔥 Quick Actions:\e[0m"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "cc" "Connect VPN"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "ram" "Detailed RAM info"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "cpu5" "Steady CPU view"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "net" "Network today"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "cdisk" "Container used disk"
    printf "   \e[1;36m%-12s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View ALL shortcuts ⚡"
fi
EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc && \
    cat /tmp/setup.sh >> /root/.bashrc && \
    chown devuser:devuser /home/devuser/.bashrc && \
    rm /tmp/setup.sh

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
