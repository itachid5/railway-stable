FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV TZ="Asia/Dhaka"

# Cleaner package-manager behavior
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV NPM_CONFIG_AUDIT=false
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_CACHE=/tmp/.npm-cache

# Phoenix runtime tuning
ENV PHOENIX_CPU_SAMPLE_SECONDS=2
ENV PHOENIX_MM_CPU_SAMPLE_SECONDS=2
ENV PHOENIX_CPU_FALLBACK_VCPU=
ENV PHOENIX_CPU_HISTORY_FILE=/tmp/.phoenix_cpu_history
ENV PHOENIX_STATE_DIR=/tmp/.phoenix_state
ENV PHOENIX_CDISK_CACHE_SECONDS=60

# --------------------------------------------------
# Base system packages
# --------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends     tzdata openssh-server sudo curl wget git nano procps net-tools iproute2 iputils-ping dnsutils     lsof htop jq speedtest-cli unzip tree python3 python3-pip python3-venv     ca-certificates gnupg psmisc     && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime     && echo $TZ > /etc/timezone     && curl -fsSL https://tailscale.com/install.sh | sh     && apt-get clean     && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# --------------------------------------------------
# Install Node.js LTS + Codex at build time
# --------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -     && apt-get install -y --no-install-recommends nodejs     && npm i -g @openai/codex --cache /tmp/.npm-cache --no-audit --no-fund     && npm cache clean --force     && rm -rf /tmp/.npm-cache /root/.npm /root/.cache/npm /root/.cache/node-gyp     && apt-get purge -y --auto-remove gnupg     && apt-get clean     && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# --------------------------------------------------
# SSH + users
# --------------------------------------------------
RUN mkdir -p /var/run/sshd     && useradd -m -s /bin/bash -u 1000 devuser     && echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers     && echo "devuser:123456" | chpasswd     && echo "root:123456" | chpasswd     && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config     && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config     && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# --------------------------------------------------
# Disable default MOTD noise
# --------------------------------------------------
RUN rm -rf /etc/update-motd.d/*     && rm -f /etc/legal     && rm -f /etc/motd     && touch /home/devuser/.hushlogin     && touch /root/.hushlogin

# --------------------------------------------------
# Prompt styling
# --------------------------------------------------
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc     && echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# --------------------------------------------------
# Main shell setup
# --------------------------------------------------
RUN mkdir -p /tmp/.phoenix_state && chmod 1777 /tmp/.phoenix_state     && cat > /tmp/setup.sh <<'EOF'
# ==========================================
# 🚀 PHOENIX TERMINAL TOOLKIT v2
# ==========================================

# ------------------------------------------
# Global tuning & paths
# ------------------------------------------
export PHOENIX_STATE_DIR="${PHOENIX_STATE_DIR:-/tmp/.phoenix_state}"
export PHOENIX_REPORT_DIR="${PHOENIX_REPORT_DIR:-$HOME/phoenix-reports}"
export PHOENIX_CPU_HISTORY_FILE="${PHOENIX_CPU_HISTORY_FILE:-/tmp/.phoenix_cpu_history}"
export PHOENIX_CPU_SAMPLE_SECONDS="${PHOENIX_CPU_SAMPLE_SECONDS:-2}"
export PHOENIX_MM_CPU_SAMPLE_SECONDS="${PHOENIX_MM_CPU_SAMPLE_SECONDS:-2}"
export PHOENIX_CDISK_CACHE_SECONDS="${PHOENIX_CDISK_CACHE_SECONDS:-60}"

# ------------------------------------------
# Basic aliases
# ------------------------------------------
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
alias dsize='du -h --max-depth=1 2>/dev/null | sort -hr'
alias chmodx='chmod +x'
alias chownme='sudo chown -R $USER:$USER .'
alias path='echo -e ${PATH//:/\\n}'
alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean && reclaimram && diskclean'
alias mem='ram'
alias hostmem='free -h'
alias cpu='cpuuse'
alias cpu5='cpuuse 5'
alias df='df -h'
alias top='htop'
alias logs='sudo tail -f /var/log/syslog'
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
alias ports='netports'
alias disk='cdisk'
alias netx='net'
alias findbig='find . -type f -size +50M -exec ls -lh {} + 2>/dev/null | awk "{ print \$9 \": \" \$5 }"'

# Python env shortcuts
alias mkv='python3 -m venv .venv && echo -e "\e[1;32m✔ .venv created successfully!\e[0m"'
alias onv='source .venv/bin/activate 2>/dev/null || echo -e "\e[1;31m✘ .venv not found! Run mkv first.\e[0m"'
alias offv='deactivate 2>/dev/null || echo -e "\e[1;33mℹ No active virtual environment to deactivate.\e[0m"'

# ------------------------------------------
# Custom shortcuts
# ------------------------------------------
CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts"
[ -f "$CUSTOM_ALIAS_FILE" ] && source "$CUSTOM_ALIAS_FILE"

function addcmd() {
    echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name (e.g., gohome) : " S_NAME
    [ -z "$S_NAME" ] && { echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; }

    if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' already exists! Please choose another name.\e[0m"
        return 1
    fi

    read -p "Command to run (e.g., cd ~)  : " S_CMD
    [ -z "$S_CMD" ] && { echo -e "\e[1;31m✘ Cancelled. Command cannot be empty.\e[0m"; return 1; }

    echo "alias $S_NAME='$S_CMD'" >> "$CUSTOM_ALIAS_FILE"
    eval "alias $S_NAME='$S_CMD'"
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' has been created and is ready to use!\e[0m\n"
}

function delcmd() {
    echo -e "\n\e[1;31m🗑️ Delete a Custom Shortcut\e[0m"
    echo -e "\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name to delete : " S_NAME
    [ -z "$S_NAME" ] && { echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; }

    if ! grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then
        echo -e "\e[1;33mℹ Shortcut '$S_NAME' not found in your custom list!\e[0m"
        return 1
    fi

    sed -i "/alias $S_NAME=/d" "$CUSTOM_ALIAS_FILE"
    unalias "$S_NAME" 2>/dev/null
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' has been successfully deleted!\e[0m\n"
}

# ------------------------------------------
# Shared helpers
# ------------------------------------------
function _state_dir() {
  local d="${PHOENIX_STATE_DIR:-/tmp/.phoenix_state}"
  mkdir -p "$d" 2>/dev/null || true
  chmod 1777 "$d" 2>/dev/null || true
  echo "$d"
}

function _report_dir() {
  local d="${PHOENIX_REPORT_DIR:-$HOME/phoenix-reports}"
  mkdir -p "$d" 2>/dev/null || true
  echo "$d"
}

function _b2h() {
  awk -v b="${1:-0}" 'BEGIN{
    split("B KB MB GB TB PB",u," ");
    i=1;
    while (b>=1024 && i<6) { b/=1024; i++ }
    printf "%.1f %s", b, u[i]
  }'
}

function _is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

function _safe_cat() {
  [ -r "$1" ] && cat "$1" 2>/dev/null || echo ""
}

function _num_or_zero() {
  local v="${1:-0}"
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "$v"
  else
    echo 0
  fi
}

function _pct() {
  awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ if (b>0) printf "%.1f", (a/b)*100; else print "0.0" }'
}

function _limit_is_real() {
  local v="${1:-0}"
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  [ "$v" -gt 0 ] || return 1
  [ "$v" -lt 1152921504606846976 ]
}

function _secs_human() {
  local s="${1:-0}" d h m
  _is_int "$s" || s=0
  d=$((s / 86400))
  h=$(((s % 86400) / 3600))
  m=$(((s % 3600) / 60))
  if [ "$d" -gt 0 ]; then
    printf "%s days, %s hours, %s mins" "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then
    printf "%s hours, %s mins" "$h" "$m"
  else
    printf "%s mins" "$m"
  fi
}

function _strip_ansi() {
  sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function _print_row() {
  local icon="$1" label="$2" a="$3" b="$4" c="$5"
  local C_C="\e[36m" C_G="\e[90m" C_W="\e[1;37m" C_R="\e[0m"
  echo -e " ${icon}   ${C_W}$(printf "%-10s" "$label")${C_R} ${C_G}::${C_R}  ${C_C}$(printf "%-18s" "$a")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-18s" "$b")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-18s" "$c")${C_R}"
}

function mkcd() { mkdir -p "$1" && cd "$1"; }
function findtext() { grep -rnw . -e "$1"; }

function kport() {
    if [ -z "$1" ]; then
        echo -e "\e[1;31m✘ Usage: kport <port>\e[0m"
        return 1
    fi
    local PID
    PID=$(sudo lsof -t -i:"$1" 2>/dev/null)
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

function procfind() {
  [ -z "$1" ] && { echo -e "\e[1;31m✘ Usage: procfind <keyword>\e[0m"; return 1; }
  ps -ef | grep -i -- "$1" | grep -v grep
}

# ------------------------------------------
# DEV helpers
# ------------------------------------------
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

    local NEED_PKGS=""
    command -v pip3 >/dev/null 2>&1 || NEED_PKGS="$NEED_PKGS python3-pip"
    python3 -m venv --help >/dev/null 2>&1 || NEED_PKGS="$NEED_PKGS python3-venv"

    if [ -z "$NEED_PKGS" ]; then
        echo -e "\e[1;32m✔ Python, pip and venv are already installed.\e[0m"
        echo -e "\e[1;36mPython Version:\e[0m $(python3 --version 2>&1)"
        echo -e "\e[1;36mPip Version:\e[0m $(pip3 --version 2>&1)"
        return 0
    fi

    echo -e "\e[1;33m⚠ Missing packages detected. Runtime install can raise file cache and RAM graph.\e[0m"
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
    echo -e "\e[1;33m⚠ Runtime install can raise file cache and RAM graph.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends golang
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Go installed successfully!\e[0m"
    go version
}

function djava() {
    echo -e "\n\e[1;36m☕ Installing Java 17 LTS...\e[0m"
    echo -e "\e[1;33m⚠ Runtime install can raise file cache and RAM graph.\e[0m"
    sudo apt-get update && sudo apt-get install -y --no-install-recommends openjdk-17-jdk openjdk-17-jre
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    sync
    echo -e "\e[1;32m✔ Java installed successfully!\e[0m"
    java -version
}

# ------------------------------------------
# App management
# ------------------------------------------
function apps() {
  echo -e "\n\e[1;36m▶ Codex / Node / Python Apps\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────\e[0m"
  ps -eo pid,user,%cpu,%mem,etime,command | grep -E '[c]odex|[n]ode|[p]ython' || echo -e "\e[90mNone\e[0m"
  echo
}

function kn() {
  sudo pkill -f node 2>/dev/null
  echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"
}

function kp() {
  sudo pkill -f python 2>/dev/null
  echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"
}

function kcodex() {
  sudo pkill -f codex 2>/dev/null
  echo -e "\e[1;32m✔ All Codex processes stopped.\e[0m"
}

# ------------------------------------------
# Memory helpers
# ------------------------------------------
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

function _mem_summary() {
  local base used limit anon file shmem slab slab_reclaimable pgt kstack sock rss reclaimable
  base="$(_cg_base)"
  [ -z "$base" ] && { echo "0|0|0|0|0|0|0|0|0|0|0"; return; }

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
  if [ "$anon" -eq 0 ] && [ "$file" -eq 0 ] && [ "$rss" -gt 0 ]; then
    anon=$rss
  fi
  reclaimable=$((file + slab_reclaimable))

  echo "$used|$limit|$anon|$file|$shmem|$slab|$slab_reclaimable|$pgt|$kstack|$sock|$rss|$reclaimable"
}

# ------------------------------------------
# CPU helpers
# ------------------------------------------
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
  echo "${PHOENIX_CPU_HISTORY_FILE:-/tmp/.phoenix_cpu_history}"
}

function _cpu_record_history() {
  local used="$1" limit="$2" pct="$3" file tmp
  file="$(_cpu_history_file)"
  tmp="${file}.tmp"
  printf '%s|%s|%s|%s\n' "$(date +%s)" "$used" "$limit" "$pct" >> "$file"
  tail -n 120 "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
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

# ------------------------------------------
# Disk helpers
# ------------------------------------------
function _container_visible_bytes() {
  local dirs=() d
  for d in /bin /boot /etc /home /lib /lib64 /opt /root /sbin /srv /tmp /usr /var /app /workspace; do
    [ -e "$d" ] && dirs+=("$d")
  done
  [ "${#dirs[@]}" -eq 0 ] && { echo 0; return; }
  du -sb "${dirs[@]}" 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

function _container_writable_bytes() {
  local dirs=() d
  for d in /home /root /var /tmp /opt /srv /app /workspace; do
    [ -e "$d" ] && dirs+=("$d")
  done
  [ "${#dirs[@]}" -eq 0 ] && { echo 0; return; }
  du -sb "${dirs[@]}" 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

function _cdisk_cache_file() {
  echo "$(_state_dir)/cdisk.cache"
}

function _cdisk_collect() {
  local visible writable total used free iused ifree ipct cache
  visible=$(_container_visible_bytes)
  writable=$(_container_writable_bytes)
  read -r total used free < <(df -B1 / 2>/dev/null | awk 'NR==2 {print $2, $3, $4}')
  read -r iused ifree ipct < <(df -Pi / 2>/dev/null | awk 'NR==2 {print $3, $4, $5}')
  cache="$(_cdisk_cache_file)"
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$(date +%s)" "${visible:-0}" "${writable:-0}" "${total:-0}" "${used:-0}" "${free:-0}" "${iused:-0}" "${ifree:-0}" "${ipct:-0%}" > "$cache"
}

function _cdisk_read() {
  local ttl="${1:-${PHOENIX_CDISK_CACHE_SECONDS:-60}}" file ts now
  file="$(_cdisk_cache_file)"
  now=$(date +%s)
  if [ -r "$file" ]; then
    ts=$(awk -F'|' 'NR==1 {print $1}' "$file" 2>/dev/null)
    if _is_int "$ts" && [ $((now - ts)) -le "$ttl" ] 2>/dev/null; then
      cat "$file"
      return
    fi
  fi
  _cdisk_collect
  cat "$file"
}

function inode() {
  echo -e "\n\e[1;36m🧬 Inode Usage\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────\e[0m"
  df -Pi /
  echo
}

function cdisk() {
  local data ts visible writable total used free iused ifree ipct fspct
  data="$(_cdisk_read 5)"
  IFS='|' read -r ts visible writable total used free iused ifree ipct <<< "$data"
  fspct=$(_pct "$used" "$total")

  echo -e "\n\e[1;36m💽 C DISK (Container Focused)\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-24s : %s\n" "Container Visible" "$(_b2h "$visible")"
  printf "  %-24s : %s\n" "Writable/App Data" "$(_b2h "$writable")"
  if _limit_is_real "$total"; then
    printf "  %-24s : %s\n" "Filesystem Total" "$(_b2h "$total")"
    printf "  %-24s : %s\n" "Filesystem Used" "$(_b2h "$used") (${fspct}%)"
    printf "  %-24s : %s\n" "Filesystem Free" "$(_b2h "$free")"
  else
    printf "  %-24s : %s\n" "Filesystem Total" "shared/unlimited"
    printf "  %-24s : %s\n" "Filesystem Used" "not fixed by runtime"
    printf "  %-24s : %s\n" "Filesystem Free" "depends on host/storage"
  fi
  printf "  %-24s : %s\n" "Inodes Used" "${iused:-0}"
  printf "  %-24s : %s\n" "Inodes Free" "${ifree:-0}"
  printf "  %-24s : %s\n" "Inode Usage" "${ipct:-0%}"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  echo -e "\e[1;33mNote:\e[0m 'Container Visible' = pseudo FS বাদ দিয়ে কন্টেইনারে দৃশ্যমান মোট ডেটা।"
  echo -e "\e[1;36mMore:\e[0m cdisktop / 15  |  cdisktop /var 15  |  diskhot / 20  |  diskclean\n"
}

function cdisktop() {
  local target="${1:-/}" limit="${2:-15}"
  [ ! -e "$target" ] && { echo -e "\e[1;31m✘ Path not found: $target\e[0m"; return 1; }
  echo -e "\n\e[1;36m📂 Largest paths in $target\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  du -xhd 1 "$target" 2>/dev/null | sort -hr | head -n "$limit"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function diskhot() {
  local target="${1:-/}" limit="${2:-20}"
  [ ! -e "$target" ] && { echo -e "\e[1;31m✘ Path not found: $target\e[0m"; return 1; }
  echo -e "\n\e[1;36m🔥 Largest files in $target\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  find "$target" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -nr | head -n "$limit" | while IFS=$'\t' read -r size path; do
    printf "  %-10s %s\n" "$(_b2h "$size")" "$path"
  done
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function diskclean() {
  local before after
  before="$(_cdisk_read 0 | awk -F'|' 'NR==1{print $2}')"
  echo -e "\n\e[1;33m🧹 Cleaning common disk caches...\e[0m"
  sudo apt-get clean >/dev/null 2>&1 || true
  npm cache clean --force >/dev/null 2>&1 || true
  python3 -m pip cache purge >/dev/null 2>&1 || true

  rm -rf "$HOME/.cache/pip" "$HOME/.cache/npm" "$HOME/.cache/node-gyp" "$HOME/.npm" /tmp/.npm-cache 2>/dev/null || true
  find /tmp -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null || true
  find /var/tmp -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null || true
  find /var/log -type f -name '*.log' -size +20M -exec truncate -s 0 {} \; 2>/dev/null || true
  sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/cache/apt/*.bin 2>/dev/null || true
  sync
  _cdisk_collect
  after="$(_cdisk_read 0 | awk -F'|' 'NR==1{print $2}')"
  echo -e "\e[1;32m✔ Done. Visible disk before: $(_b2h "$before") | after: $(_b2h "$after")\e[0m\n"
}

# ------------------------------------------
# Network helpers
# ------------------------------------------
function _net_iface_list() {
  local v
  v=$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | paste -sd ',' -)
  if [ -n "$v" ]; then
    echo "$v"
  else
    ip -o route 2>/dev/null | awk '/ dev / {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | grep -v '^lo$' | sort -u | paste -sd ',' -
  fi
}

function _net_primary_iface() {
  local iface
  iface=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
  [ -n "$iface" ] && echo "$iface" || echo "unknown"
}

function _net_raw_totals() {
  local rx=0 tx=0 rxp=0 txp=0 rxe=0 txe=0 rxd=0 txd=0 count=0 iface base
  for base in /sys/class/net/*; do
    [ -e "$base" ] || continue
    iface=$(basename "$base")
    [ "$iface" = "lo" ] && continue
    [ -d "$base/statistics" ] || continue
    rx=$((rx + $(_safe_cat "$base/statistics/rx_bytes")))
    tx=$((tx + $(_safe_cat "$base/statistics/tx_bytes")))
    rxp=$((rxp + $(_safe_cat "$base/statistics/rx_packets")))
    txp=$((txp + $(_safe_cat "$base/statistics/tx_packets")))
    rxe=$((rxe + $(_safe_cat "$base/statistics/rx_errors")))
    txe=$((txe + $(_safe_cat "$base/statistics/tx_errors")))
    rxd=$((rxd + $(_safe_cat "$base/statistics/rx_dropped")))
    txd=$((txd + $(_safe_cat "$base/statistics/tx_dropped")))
    count=$((count + 1))
  done
  echo "$rx|$tx|$rxp|$txp|$rxe|$txe|$rxd|$txd|$count"
}

function _net_state_file() {
  echo "$(_state_dir)/net_daily.state"
}

function _net_reset_baseline_internal() {
  local cur file today
  cur="$(_net_raw_totals)"
  file="$(_net_state_file)"
  today=$(date +%F)
  printf '%s|%s\n' "$today" "$cur" > "$file"
}

function _net_ensure_baseline() {
  local file today saved
  file="$(_net_state_file)"
  today=$(date +%F)
  if [ ! -r "$file" ]; then
    _net_reset_baseline_internal
    return
  fi
  saved=$(awk -F'|' 'NR==1 {print $1}' "$file" 2>/dev/null)
  [ "$saved" != "$today" ] && _net_reset_baseline_internal
}

function _net_today_totals() {
  local cur day base_rx base_tx base_rxp base_txp base_rxe base_txe base_rxd base_txd
  local rx tx rxp txp rxe txe rxd txd ifc
  _net_ensure_baseline
  cur="$(_net_raw_totals)"
  IFS='|' read -r rx tx rxp txp rxe txe rxd txd ifc <<< "$cur"
  IFS='|' read -r day base_rx base_tx base_rxp base_txp base_rxe base_txe base_rxd base_txd < "$(_net_state_file)"
  echo "$((rx - base_rx))|$((tx - base_tx))|$((rxp - base_rxp))|$((txp - base_txp))|$((rxe - base_rxe))|$((txe - base_txe))|$((rxd - base_rxd))|$((txd - base_txd))"
}

function _net_conn_counts() {
  local estab listen timewait udp
  estab=$(ss -tanH state established 2>/dev/null | wc -l | tr -d ' ')
  listen=$(ss -tulnH 2>/dev/null | wc -l | tr -d ' ')
  timewait=$(ss -tanH state time-wait 2>/dev/null | wc -l | tr -d ' ')
  udp=$(ss -uanH 2>/dev/null | wc -l | tr -d ' ')
  echo "${estab:-0}|${listen:-0}|${timewait:-0}|${udp:-0}"
}

function netreset() {
  _net_reset_baseline_internal
  echo -e "\e[1;32m✔ Network daily baseline reset for $(date +%F).\e[0m"
}

function nettoday() {
  local today iface primary cur conn
  local drx dtx drxp dtxp drxe dtxe drxd dtxd
  local rx tx rxp txp rxe txe rxd txd ifcount
  cur="$(_net_raw_totals)"
  IFS='|' read -r rx tx rxp txp rxe txe rxd txd ifcount <<< "$cur"
  today="$(_net_today_totals)"
  IFS='|' read -r drx dtx drxp dtxp drxe dtxe drxd dtxd <<< "$today"
  conn="$(_net_conn_counts)"
  IFS='|' read -r estab listen timewait udp <<< "$conn"
  iface="$(_net_iface_list)"
  primary="$(_net_primary_iface)"

  echo -e "\n\e[1;36m🌐 NETWORK TODAY (Container Tracked)\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-24s : %s\n" "Primary Interface" "$primary"
  printf "  %-24s : %s\n" "Interfaces" "${iface:-none}"
  printf "  %-24s : %s\n" "Today Download" "$(_b2h "$drx")"
  printf "  %-24s : %s\n" "Today Upload" "$(_b2h "$dtx")"
  printf "  %-24s : %s\n" "Today RX Packets" "${drxp:-0}"
  printf "  %-24s : %s\n" "Today TX Packets" "${dtxp:-0}"
  printf "  %-24s : %s\n" "Current Total RX" "$(_b2h "$rx")"
  printf "  %-24s : %s\n" "Current Total TX" "$(_b2h "$tx")"
  printf "  %-24s : %s\n" "Errors (RX/TX)" "${drxe:-0}/${dtxe:-0}"
  printf "  %-24s : %s\n" "Dropped (RX/TX)" "${drxd:-0}/${dtxd:-0}"
  printf "  %-24s : %s\n" "Established Conns" "${estab:-0}"
  printf "  %-24s : %s\n" "Listening Ports" "${listen:-0}"
  printf "  %-24s : %s\n" "Time-Wait / UDP" "${timewait:-0} / ${udp:-0}"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  echo -e "\e[1;33mTip:\e[0m live speed = netlive 1 | detailed connections = netconn | open ports = netports\n"
}

function net() {
  nettoday
}

function netlive() {
  local secs="${1:-1}"
  local a b arx atx brx btx down up dr du
  echo -e "\e[1;36mLive network speed monitor. Press Ctrl+C to stop.\e[0m"
  sleep 1
  while true; do
    a="$(_net_raw_totals)"
    IFS='|' read -r arx atx _ <<< "$a"
    sleep "$secs"
    b="$(_net_raw_totals)"
    IFS='|' read -r brx btx _ <<< "$b"
    dr=$((brx - arx))
    du=$((btx - atx))
    down=$(awk -v x="$dr" -v s="$secs" 'BEGIN{ if(s>0) printf "%.2f", x/s; else print "0" }')
    up=$(awk -v x="$du" -v s="$secs" 'BEGIN{ if(s>0) printf "%.2f", x/s; else print "0" }')
    clear
    echo -e "\n\e[1;36m📶 Live Network Throughput\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────\e[0m"
    printf "  %-16s : %s/s\n" "Download" "$(_b2h "$down")"
    printf "  %-16s : %s/s\n" "Upload" "$(_b2h "$up")"
    printf "  %-16s : %s sec\n" "Window" "$secs"
    echo -e "\e[90m────────────────────────────────────────────────────────\e[0m"
  done
}

function netconn() {
  echo -e "\n\e[1;36m🔌 Network Connections\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  printf "  %-24s : %s\n" "Established" "$(ss -tanH state established 2>/dev/null | wc -l | tr -d ' ')"
  printf "  %-24s : %s\n" "Listening" "$(ss -tulnH 2>/dev/null | wc -l | tr -d ' ')"
  printf "  %-24s : %s\n" "Time-Wait" "$(ss -tanH state time-wait 2>/dev/null | wc -l | tr -d ' ')"
  printf "  %-24s : %s\n" "UDP Sockets" "$(ss -uanH 2>/dev/null | wc -l | tr -d ' ')"
  echo -e "\n\e[1;33mTop remote addresses:\e[0m"
  ss -tpnH state established 2>/dev/null | awk '{print $5}' | sed 's/\[//g; s/\]//g; s/:[0-9]*$//' | sort | uniq -c | sort -nr | head -n 10
  echo -e "\n\e[1;33mTop listening sockets:\e[0m"
  ss -tulpen 2>/dev/null | sed -n '1,20p'
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function netports() {
  echo -e "\n\e[1;36m🚪 Open / Listening Ports\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  ss -tulpen 2>/dev/null || sudo netstat -tulpn
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ------------------------------------------
# RAM tools
# ------------------------------------------
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
  local m used limit anon file shmem slab pgt kstack sock rss reclaimable codex_proc node_proc py_proc
  m="$(_mem_summary)"
  IFS='|' read -r used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable <<< "$m"
  codex_proc=$(pgrep -af '(^|/)(codex)( |$)|@openai/codex' 2>/dev/null | head -n 3)
  node_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[n]ode|[n]pm' | head -n 5)
  py_proc=$(ps -eo pid=,rss=,comm=,args= --sort=-rss | grep -E '[p]ython' | head -n 5)

  echo -e "\n\e[1;35m🔎 RAM Diagnosis\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"

  if [ "$file" -gt "$anon" ] && [ "$file" -gt $((150*1024*1024)) ]; then
    echo -e "\e[1;33mMain Cause:\e[0m File/Page cache is dominating memory."
  elif [ "$anon" -gt $((200*1024*1024)) ]; then
    echo -e "\e[1;33mMain Cause:\e[0m Real process/application memory is high (anon memory)."
  else
    echo -e "\e[1;33mMain Cause:\e[0m Mixed usage."
  fi

  [ -n "$codex_proc" ] && { echo -e "\n\e[1;31m⚠ Codex appears to be running:\e[0m"; echo "$codex_proc"; }
  [ -n "$node_proc" ] && { echo -e "\n\e[1;36mNode/NPM processes:\e[0m"; echo "$node_proc"; }
  [ -n "$py_proc" ] && { echo -e "\n\e[1;36mPython processes:\e[0m"; echo "$py_proc"; }

  echo -e "\n\e[1;32mWhat to do now:\e[0m"
  echo -e "  1) Run \e[1;36mram\e[0m and check File Cache vs Anon Memory"
  echo -e "  2) Run \e[1;36mcachefiles\e[0m to see cache folders"
  echo -e "  3) If File Cache is high, run \e[1;36mreclaimram\e[0m"
  echo -e "  4) If Anon/Process memory is high, run \e[1;36mramtop\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function ram() {
  local m used limit anon file shmem slab slab_reclaimable pgt kstack sock rss reclaimable free limit_txt free_txt used_pct
  m="$(_mem_summary)"
  IFS='|' read -r used limit anon file shmem slab slab_reclaimable pgt kstack sock rss reclaimable <<< "$m"

  if _limit_is_real "$limit"; then
    free=$((limit - used))
    [ "$free" -lt 0 ] && free=0
    limit_txt="$(_b2h "$limit")"
    free_txt="$(_b2h "$free")"
    used_pct="$( _pct "$used" "$limit")%"
  else
    limit_txt="shared/unlimited"
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
  fi

  ram
}

# ------------------------------------------
# CPU tools
# ------------------------------------------
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
  local secs="${1:-${PHOENIX_CPU_SAMPLE_SECONDS:-2}}"
  local data used limit pct thr_usec thr_pct thr_n psi_some psi_full sample avg30 limit_label

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
  echo -e "\e[1;33mTip:\e[0m For calmer value, run \e[1;36mcpu 5\e[0m or \e[1;36mcpulive 2\e[0m.\n"
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
  elif [ "$pct" != "-" ] && awk -v p="$pct" 'BEGIN { exit !(p>=70) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m Real CPU load is high."
  elif awk -v s="$psi_some" 'BEGIN { exit !(s>=5.0) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m CPU pressure is noticeable."
  elif [ -n "$avg30" ] && awk -v a="$avg30" -v u="$used" 'BEGIN { exit !(a>0.05 && u<(a/2)) }'; then
    echo -e "\e[1;33mMain Cause:\e[0m Current instant is calmer than recent history."
  else
    echo -e "\e[1;33mMain Cause:\e[0m Current CPU usage looks low or moderate."
  fi

  echo -e "\n\e[1;36mCurrent Sample:\e[0m"
  echo -e "  Used           : ${used} vCPU"
  echo -e "  Sample Window  : ${sample}s"
  [ "$pct" != "-" ] && echo -e "  Percent Limit  : ${pct}%" || echo -e "  Percent Limit  : shared / not fixed"
  echo -e "  Throttle Events: ${thr_n}"
  echo -e "  Throttle Time  : ${thr_pct}%"
  echo -e "  PSI some avg10 : ${psi_some}%"
  echo -e "  PSI full avg10 : ${psi_full}%"
  [ -n "$avg30" ] && echo -e "  Local Avg 30s  : ${avg30} vCPU"

  echo -e "\n\e[1;32mWhat to do now:\e[0m"
  echo -e "  1) Run \e[1;36mcpu 5\e[0m for a steadier reading"
  echo -e "  2) Run \e[1;36mcputop\e[0m to catch busy processes"
  echo -e "  3) Run \e[1;36mcpulive 2\e[0m for a live view"
  echo -e "  4) Run \e[1;36mcginfo\e[0m to inspect raw cgroup CPU settings"
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
  [ -f /sys/fs/cgroup/memory.current ] && printf "  %-22s : %s\n" "memory.current" "$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"
  [ -f /sys/fs/cgroup/memory.max ] && printf "  %-22s : %s\n" "memory.max" "$(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ------------------------------------------
# Health, dashboard, snapshot
# ------------------------------------------
function health() {
  local m used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable
  local ram_pct ram_state cpu_data cpu_used cpu_limit cpu_pct thr thr_pct thr_n psi_some psi_full sample cpu_state
  local d ts visible writable total dused dfree iused ifree ipct disk_pct disk_state
  local conn estab listen tw udp pids

  m="$(_mem_summary)"
  IFS='|' read -r used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable <<< "$m"
  ram_pct=$(_pct "$used" "$limit")

  cpu_data="$(_cpu_measure 2)"
  IFS='|' read -r cpu_used cpu_limit cpu_pct thr thr_pct thr_n psi_some psi_full sample <<< "$cpu_data"

  d="$(_cdisk_read 5)"
  IFS='|' read -r ts visible writable total dused dfree iused ifree ipct <<< "$d"
  disk_pct=$(_pct "$dused" "$total")

  conn="$(_net_conn_counts)"
  IFS='|' read -r estab listen tw udp <<< "$conn"
  pids=$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')

  if _limit_is_real "$limit" && awk -v v="$ram_pct" 'BEGIN{exit !(v>=90)}'; then ram_state="ALERT"; elif _limit_is_real "$limit" && awk -v v="$ram_pct" 'BEGIN{exit !(v>=75)}'; then ram_state="WARN"; elif _limit_is_real "$limit"; then ram_state="OK"; else ram_state="INFO"; fi
  if [ "$cpu_pct" != "-" ] && awk -v v="$cpu_pct" 'BEGIN{exit !(v>=90)}'; then cpu_state="ALERT"; elif [ "$cpu_pct" != "-" ] && awk -v v="$cpu_pct" 'BEGIN{exit !(v>=75)}'; then cpu_state="WARN"; else cpu_state="OK"; fi
  if _limit_is_real "$total" && awk -v v="$disk_pct" 'BEGIN{exit !(v>=90)}'; then disk_state="ALERT"; elif _limit_is_real "$total" && awk -v v="$disk_pct" 'BEGIN{exit !(v>=75)}'; then disk_state="WARN"; else disk_state="INFO"; fi

  echo -e "\n\e[1;36m🩺 System Health\e[0m"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m"
  if _limit_is_real "$limit"; then
    printf "  %-16s : %-6s | %s%% of limit\n" "RAM" "$ram_state" "$ram_pct"
  else
    printf "  %-16s : %-6s | shared / no fixed cap\n" "RAM" "$ram_state"
  fi
  if [ "$cpu_pct" != "-" ]; then
    printf "  %-16s : %-6s | %s%% of limit\n" "CPU" "$cpu_state" "$cpu_pct"
  else
    printf "  %-16s : %-6s | shared / no fixed cap\n" "CPU" "$cpu_state"
  fi
  if _limit_is_real "$total"; then
    printf "  %-16s : %-6s | %s%% of filesystem\n" "DISK" "$disk_state" "$disk_pct"
  else
    printf "  %-16s : %-6s | host-managed / no fixed cap\n" "DISK" "$disk_state"
  fi
  printf "  %-16s : %-6s | %s listening, %s established\n" "NETWORK" "INFO" "${listen:-0}" "${estab:-0}"
  printf "  %-16s : %-6s | %s processes running\n" "PIDS" "INFO" "${pids:-0}"
  echo -e "\e[90m────────────────────────────────────────────────────────────────────\e[0m\n"
}

function snapshotjson() {
  local out ts m used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable
  local cpu_data cpu_used cpu_limit cpu_pct thr thr_pct thr_n psi_some psi_full sample
  local d cvisible writable total dused dfree iused ifree ipct
  local cur rx tx rxp txp rxe txe rxd txd ifcount
  local today drx dtx drxp dtxp drxe dtxe drxd dtxd
  local conn estab listen tw udp

  ts=$(date +%Y%m%d-%H%M%S)
  out="$(_report_dir)/phoenix-report-${ts}.json"

  m="$(_mem_summary)"
  IFS='|' read -r used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable <<< "$m"
  cpu_data="$(_cpu_measure 1)"
  IFS='|' read -r cpu_used cpu_limit cpu_pct thr thr_pct thr_n psi_some psi_full sample <<< "$cpu_data"
  d="$(_cdisk_read 5)"
  IFS='|' read -r _ cvisible writable total dused dfree iused ifree ipct <<< "$d"
  cur="$(_net_raw_totals)"
  IFS='|' read -r rx tx rxp txp rxe txe rxd txd ifcount <<< "$cur"
  today="$(_net_today_totals)"
  IFS='|' read -r drx dtx drxp dtxp drxe dtxe drxd dtxd <<< "$today"
  conn="$(_net_conn_counts)"
  IFS='|' read -r estab listen tw udp <<< "$conn"

  cat > "$out" <<JSON
{
  "timestamp": "$(date --iso-8601=seconds)",
  "user": "$USER",
  "home": "$HOME",
  "memory": {
    "used_bytes": ${used:-0},
    "limit_bytes": ${limit:-0},
    "anon_bytes": ${anon:-0},
    "file_cache_bytes": ${file:-0},
    "rss_sum_bytes": ${rss:-0},
    "reclaimable_bytes": ${reclaimable:-0}
  },
  "cpu": {
    "used_vcpu": ${cpu_used:-0},
    "limit_vcpu": ${cpu_limit:-0},
    "percent_of_limit": "${cpu_pct:-0}",
    "throttle_events": ${thr_n:-0},
    "throttle_percent": ${thr_pct:-0},
    "psi_some_avg10": ${psi_some:-0},
    "psi_full_avg10": ${psi_full:-0}
  },
  "disk": {
    "container_visible_bytes": ${cvisible:-0},
    "writable_bytes": ${writable:-0},
    "filesystem_total_bytes": ${total:-0},
    "filesystem_used_bytes": ${dused:-0},
    "filesystem_free_bytes": ${dfree:-0},
    "inode_used": ${iused:-0},
    "inode_free": ${ifree:-0},
    "inode_percent": "${ipct:-0%}"
  },
  "network": {
    "interfaces": "$(_net_iface_list)",
    "primary": "$(_net_primary_iface)",
    "total_rx_bytes": ${rx:-0},
    "total_tx_bytes": ${tx:-0},
    "today_rx_bytes": ${drx:-0},
    "today_tx_bytes": ${dtx:-0},
    "today_rx_packets": ${drxp:-0},
    "today_tx_packets": ${dtxp:-0},
    "today_rx_errors": ${drxe:-0},
    "today_tx_errors": ${dtxe:-0},
    "today_rx_dropped": ${drxd:-0},
    "today_tx_dropped": ${dtxd:-0},
    "established": ${estab:-0},
    "listening": ${listen:-0},
    "time_wait": ${tw:-0},
    "udp": ${udp:-0}
  }
}
JSON
  echo -e "\e[1;32m✔ JSON snapshot saved: $out\e[0m"
}

function snapshot() {
  local out ts
  ts=$(date +%Y%m%d-%H%M%S)
  out="$(_report_dir)/phoenix-report-${ts}.txt"
  {
    echo "PHOENIX REPORT"
    echo "Generated: $(date)"
    echo "User: $USER"
    echo "Home: $HOME"
    echo
    mm
    health
    ram
    cpuuse 2
    cdisk
    net
    cputop
    ramtop
  } | _strip_ansi > "$out"
  echo -e "\e[1;32m✔ Text snapshot saved: $out\e[0m"
}

function diag() {
  mm
  health
  cpuwhy 3
  ramwhy
  cdisk
  net
  cachefiles
}

function mm() {
  local m used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable free used_pct
  local cpu_data cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample avg30
  local d ts visible writable total dused dfree iused ifree ipct
  local today drx dtx drxp dtxp drxe dtxe drxd dtxd
  local conn estab listen tw udp
  local pids home_items uptime_sec uptime_h
  local C_G="\e[90m" C_W="\e[1;37m" C_C="\e[36m" C_R="\e[0m"

  m="$(_mem_summary)"
  IFS='|' read -r used limit anon file shmem slab slabrec pgt kstack sock rss reclaimable <<< "$m"

  if _limit_is_real "$limit"; then
    free=$((limit - used))
    [ "$free" -lt 0 ] && free=0
    used_pct="$( _pct "$used" "$limit")%"
  else
    free=0
    used_pct="shared/unlimited"
  fi

  cpu_data="$(_cpu_measure "${PHOENIX_MM_CPU_SAMPLE_SECONDS:-2}")"
  IFS='|' read -r cpu_used cpu_limit cpu_pct cpu_thr cpu_thr_pct cpu_thr_n cpu_psi_some cpu_psi_full cpu_sample <<< "$cpu_data"
  avg30=$(_cpu_avg_history 30 2>/dev/null || true)
  [ -z "$avg30" ] && avg30="$cpu_used"

  d="$(_cdisk_read 5)"
  IFS='|' read -r ts visible writable total dused dfree iused ifree ipct <<< "$d"

  today="$(_net_today_totals)"
  IFS='|' read -r drx dtx drxp dtxp drxe dtxe drxd dtxd <<< "$today"
  conn="$(_net_conn_counts)"
  IFS='|' read -r estab listen tw udp <<< "$conn"

  pids=$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')
  home_items=$(find "$HOME" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  uptime_sec=$(ps -o etimes= -p 1 2>/dev/null | xargs)
  _is_int "$uptime_sec" || uptime_sec=0
  uptime_h=$(_secs_human "$uptime_sec")

  echo -e "\n${C_W}▶ SYSTEM MONITOR (Container Accurate)${C_R}"
  echo -e "${C_G}────────────────────────────────────────────────────────────────────${C_R}"
  if _limit_is_real "$limit"; then
    _print_row "❖" "RAM" "$(_b2h "$limit") Max" "$(_b2h "$used") Used" "$(_b2h "$free") Free"
  else
    _print_row "❖" "RAM" "shared/unlimited" "$(_b2h "$used") Used" "host-managed"
  fi
  _print_row "≣" "CACHE" "$(_b2h "$file") File" "$(_b2h "$anon") Anon" "$(_b2h "$rss") RSS"
  if awk -v v="$cpu_limit" 'BEGIN { exit !(v>0) }'; then
    _print_row "⚙" "CPU" "${cpu_limit} vCPU Max" "${cpu_used} vCPU ${cpu_sample}s" "${cpu_pct}% Limit"
  else
    _print_row "⚙" "CPU" "shared/auto" "${cpu_used} vCPU ${cpu_sample}s" "no fixed cap"
  fi
  _print_row "⌁" "CPU+" "${avg30} vCPU 30s" "${cpu_thr_pct}% Throttle" "${cpu_psi_some}% PSI10"
  if _limit_is_real "$total"; then
    _print_row "⛁" "C DISK" "$(_b2h "$visible") Visible" "$(_b2h "$writable") Writable" "$(_b2h "$dfree") Free"
  else
    _print_row "⛁" "C DISK" "$(_b2h "$visible") Visible" "$(_b2h "$writable") Writable" "host-managed free"
  fi
  _print_row "⇅" "NET TODAY" "$(_b2h "$drx") Down" "$(_b2h "$dtx") Up" "$((drxp + dtxp)) Pkts"
  _print_row "☍" "CONN" "${estab} Estab" "${listen} Listen" "${udp} UDP"
  _print_row "▣" "SYSTEM" "${pids} PIDs" "${home_items} HomeItems" "${uptime_h}"
  echo -e "${C_G}────────────────────────────────────────────────────────────────────${C_R}"
  echo -e " ${C_W}RAM%${C_R}      ${C_G}::${C_R}  ${C_C}${used_pct}${C_R}"
  echo -e " ${C_W}RECLAIM${C_R}   ${C_G}::${C_R}  ${C_C}$(_b2h "$reclaimable") likely reclaimable${C_R}"
  echo -e " ${C_W}CPU NOW${C_R}   ${C_G}::${C_R}  ${C_C}${cpu_used} vCPU (${cpu_sample}s avg)${C_R}"
  echo -e " ${C_W}PORTS${C_R}     ${C_G}::${C_R}  ${C_C}${listen} open/listening${C_R}"
  echo -e "${C_G}────────────────────────────────────────────────────────────────────${C_R}\n"
}

# ------------------------------------------
# Tailscale helpers
# ------------------------------------------
function cc() {
    if pgrep -x "tailscaled" > /dev/null; then
        echo -e "\e[1;33mℹ Tailscale daemon is running.\e[0m"
    else
        echo -e "\e[1;33m⌛ Starting Tailscale in background...\e[0m"
        nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 &
        sleep 3
    fi

    local TS_KEY_FILE="$HOME/.ts_auth_key"
    local TS_KEY=""

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
        read -p "Enter Tailscale Auth Key: " TS_KEY
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

# ------------------------------------------
# MOTD / Login dashboard
# ------------------------------------------
function custom_motd() {
    local OS_VERSION KERNEL_VERSION ARCH CPU_MODEL LAST_LOGIN_FILE LAST_LOGIN_DATA LAST_LOGIN_TIME LAST_LOGIN_IP CURRENT_IP UPTIME_SEC MY_UPTIME
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
    _is_int "$UPTIME_SEC" || UPTIME_SEC=0
    MY_UPTIME=$(_secs_human "$UPTIME_SEC")

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

# ------------------------------------------
# Command menu
# ------------------------------------------
function pcmd() {
    printf "   \e[1;32m%-18s\e[0m : %s\n" "$1" "$2"
}

function cmds() {
    echo -e "\n\e[1;37m⚡ ALL PHOENIX SHORTCUTS ⚡\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────────────────────────────\e[0m"

    echo -e "\e[1;33m📁 Navigation & Files\e[0m"
    pcmd "c" "Clear screen"
    pcmd ".. / ..." "Go back folders"
    pcmd "ll / la" "List files"
    pcmd "sz / dsize" "Size summary"
    pcmd "mkcd <dir>" "Create and enter directory"
    pcmd "tree" "Visual tree"
    pcmd "ex <file>" "Extract archive"
    pcmd "findbig" "Find files >50MB"
    pcmd "findtext <txt>" "Search text in files"
    pcmd "diskhot [path] [n]" "Largest files"
    pcmd "cdisktop [p] [n]" "Largest directories"

    echo -e "\n\e[1;33m💻 System & Health\e[0m"
    pcmd "mm" "Main dashboard"
    pcmd "health" "Health summary"
    pcmd "diag" "Full diagnosis"
    pcmd "ram / ramtop" "RAM summary / top"
    pcmd "ramwhy" "Explain RAM usage"
    pcmd "cachefiles" "Show cache folders"
    pcmd "reclaimram" "Clean RAM-related caches"
    pcmd "cpu / cpu5" "CPU usage"
    pcmd "cputop" "Top CPU processes"
    pcmd "cpulive [s]" "Live CPU monitor"
    pcmd "cpuwhy [s]" "Explain CPU spikes"
    pcmd "cpuavg [s]" "Average CPU history"
    pcmd "cginfo" "Raw cgroup info"
    pcmd "cdisk" "Container disk summary"
    pcmd "inode" "Inode usage"
    pcmd "diskclean" "Clean disk caches"

    echo -e "\n\e[1;33m🌐 Network & Ports\e[0m"
    pcmd "net / nettoday" "Tracked daily network"
    pcmd "netlive [s]" "Live network throughput"
    pcmd "netconn" "Connection summary"
    pcmd "netports" "Open ports"
    pcmd "netreset" "Reset daily net counter"
    pcmd "myip" "Public IP details"
    pcmd "speed" "Internet speed test"
    pcmd "pinger" "Ping 8.8.8.8"
    pcmd "cc / cs / ts" "Tailscale connect/stop/status"

    echo -e "\n\e[1;33m🎯 Processes & Apps\e[0m"
    pcmd "apps" "Show Codex/Node/Python apps"
    pcmd "procfind <txt>" "Search running process"
    pcmd "kport <port>" "Kill process on port"
    pcmd "kn / kp / kcodex" "Kill Node / Python / Codex"
    pcmd "ports" "Same as netports"

    echo -e "\n\e[1;33m🛠️ Dev, Report & Tools\e[0m"
    pcmd "snapshot" "Save text report"
    pcmd "snapshotjson" "Save JSON report"
    pcmd "weather" "Weather in Dhaka"
    pcmd "gs ga gc gp gl" "Git shortcuts"
    pcmd "mkv / onv / offv" "Virtualenv shortcuts"
    pcmd "sv" "Smart activate venv"
    pcmd "dcodex" "Codex status"
    pcmd "dpy / dgo / djava" "Prepare Python / Go / Java"
    pcmd "serve" "Host current folder on :8000"
    pcmd "addcmd / delcmd" "Custom shortcuts"

    echo -e "\n\e[1;35m👤 My Personal Shortcuts\e[0m"
    if [ -f "$CUSTOM_ALIAS_FILE" ] && [ -s "$CUSTOM_ALIAS_FILE" ]; then
        cat "$CUSTOM_ALIAS_FILE" | sed "s/alias //g" | sed "s/='/|/g" | sed "s/'//g" | while IFS='|' read -r name cmd; do
            pcmd "$name" "$cmd"
        done
    else
        echo -e "   \e[90mNo personal shortcuts yet. Type 'addcmd' to create one.\e[0m"
    fi

    echo -e "\e[90m────────────────────────────────────────────────────────────────────────────\e[0m\n"
}

# ------------------------------------------
# Clean login screen
# ------------------------------------------
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;33m🔥 Quick Actions:\e[0m"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "cmds" "View all shortcuts"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "health" "System health summary"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "cdisk" "Container disk details"
    printf "   \e[1;32m%-12s\e[0m : %s\n" "net" "Network today summary"
    printf "   \e[1;32m%-12s\e[0m : %s\n\n" "snapshot" "Save full report"
fi

EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc     && cat /tmp/setup.sh >> /root/.bashrc     && mkdir -p /home/devuser/phoenix-reports /root/phoenix-reports /tmp/.phoenix_state     && chmod 1777 /tmp/.phoenix_state     && chown -R devuser:devuser /home/devuser     && rm /tmp/setup.sh

# --------------------------------------------------
# Startup script
# --------------------------------------------------
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e
mkdir -p /tmp/.phoenix_state
chmod 1777 /tmp/.phoenix_state || true
/usr/sbin/sshd
tail -f /dev/null
SH

RUN sed -i 's/
$//' /start.sh && chmod +x /start.sh

WORKDIR /home/devuser
EXPOSE 22
CMD ["/start.sh"]
