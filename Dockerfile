FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
# ঢাকা, বাংলাদেশ টাইমজোন সেট করা হচ্ছে
ENV TZ="Asia/Dhaka"

# প্রয়োজনীয় প্যাকেজ এবং টাইমজোন (tzdata) সেটআপ
RUN apt-get update && apt-get install -y \
    tzdata openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils lsof htop jq speedtest-cli unzip tree python3 \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

# SSH ফোল্ডার তৈরি এবং ইউজার/পাসওয়ার্ড সেটআপ
RUN mkdir -p /var/run/sshd && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# ডিফল্ট ওয়েলকাম মেসেজ বন্ধ করা হচ্ছে
RUN rm -rf /etc/update-motd.d/* && \
    rm -f /etc/legal && \
    rm -f /etc/motd && \
    touch /home/devuser/.hushlogin && \
    touch /root/.hushlogin

# ১. প্রম্পট (PS1) স্টাইল সেটআপ
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# ২. সমস্ত ফাংশন এবং সুপার শর্টকাট
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

# 🌟 NEW: Extra File & Nav Shortcuts
alias dsize='du -h --max-depth=1 | sort -hr'
alias chmodx='chmod +x'
alias chownme='sudo chown -R $USER:$USER .'
alias path='echo -e ${PATH//:/\\n}'

# System
alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean'
alias mem='free -h'
alias df='df -h'
alias top='htop'
alias ports='sudo netstat -tulpn'
alias logs='sudo tail -f /var/log/syslog'
alias rst='source ~/.bashrc && echo -e "\e[1;32m✔ Terminal Reloaded!\e[0m"'

# 🌟 NEW: Extra System Shortcuts
alias sysinfo='cat /etc/os-release'
alias cpuinfo='lscpu'
alias myports='ss -tuln'
alias histg='history | grep'

# Network & VPN
alias myip='echo -e "\n\e[1;36m🌐 IP Details:\e[0m"; curl -s ipinfo.io; echo'
alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple'
alias ping='ping -c 4'
alias ts='sudo tailscale status'

# 🌟 NEW: Extra Network Shortcuts
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
# আবহাওয়া ঢাকার জন্য সেট করা হয়েছে
alias weather='curl -s wttr.in/Dhaka?0'

# 🌟 NEW: Python Venv Shortcuts
alias mkv='python3 -m venv .venv && echo -e "\e[1;32m✔ .venv created successfully!\e[0m"'
alias onv='source .venv/bin/activate 2>/dev/null || echo -e "\e[1;31m✘ .venv not found! Run mkv first.\e[0m"'
alias offv='deactivate 2>/dev/null || echo -e "\e[1;33mℹ No active virtual environment to deactivate.\e[0m"'

# Apps Management
alias apps='echo -e "\n\e[1;36m▶ Node/Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"'
alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"'
alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"'

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
    pcmd "clean" "Clean system cache and junk files"
    pcmd "mem" "Show RAM usage"
    pcmd "ram" "Detailed Container RAM Breakdown 🔥"
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
    pcmd "apps" "List all running Node/Python apps"
    pcmd "kn" "Kill all Node.js apps"
    pcmd "kp" "Kill all Python apps"
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
    pcmd "dcodex" "Auto-install Node.js & run Codex 🌟"
    pcmd "dpy" "Auto-install Python, Pip & Virtualenv 🌟"
    pcmd "dgo" "Auto-install Golang 🌟"
    pcmd "djava" "Auto-install Java 17 LTS 🌟"
    
    # Custom Shortcuts Section
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

# Advanced Functions
function mkcd() { mkdir -p "$1" && cd "$1"; }
function findtext() { grep -rnw . -e "$1"; }

function kport() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: kport <port>\e[0m"; return 1; fi
    PID=$(sudo lsof -t -i:$1)
    if [ -z "$PID" ]; then echo -e "\e[1;33mℹ Port $1 is free\e[0m"
    else sudo kill -9 $PID; echo -e "\e[1;32m✔ Killed process on port $1\e[0m"; fi
}

function ex() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: ex <filename>\e[0m"; return 1; fi
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.bz2) bunzip2 "$1" ;;
            *.rar) unrar e "$1" ;; *.gz) gunzip "$1" ;; *.tar) tar xf "$1" ;;
            *.zip) unzip "$1" ;; *) echo -e "\e[1;31m✘ Cannot extract '$1'\e[0m" ;;
        esac
    else echo -e "\e[1;31m✘ '$1' is not a valid file\e[0m"; fi
}

# ==========================================
# 🌟 NEW DEV SHORTCUTS & INSTALLERS (WITH AUTO CACHE CLEANUP)
# ==========================================

function sv() {
    if [ -f "venv/bin/activate" ]; then source venv/bin/activate; echo -e "\e[1;32m✔ venv activated!\e[0m";
    elif [ -f ".venv/bin/activate" ]; then source .venv/bin/activate; echo -e "\e[1;32m✔ .venv activated!\e[0m";
    elif [ -f "env/bin/activate" ]; then source env/bin/activate; echo -e "\e[1;32m✔ env activated!\e[0m";
    else echo -e "\e[1;31m✘ No virtual environment (venv, .venv, env) found in this directory!\e[0m\n\e[1;33mℹ Run 'mkv' to create one.\e[0m"; fi
}

function dcodex() {
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
        echo -e "\n\e[1;33m⌛ Installing NVM & Node.js...\e[0m"
        sudo apt update && sudo apt install -y curl
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v node &> /dev/null; then
        echo -e "\e[1;33m⌛ Installing Node LTS...\e[0m"
        nvm install --lts
    fi
    
    if ! command -v codex &> /dev/null; then
        echo -e "\e[1;33m⌛ Installing OpenAI Codex...\e[0m"
        npm i -g @openai/codex
    fi
    
    # 🧹 RAM বাঁচানোর জন্য অপ্রয়োজনীয় ক্যাশ ক্লিন করা হচ্ছে
    echo -e "\e[1;35m🧹 Cleaning up cache to free RAM...\e[0m"
    npm cache clean --force 2>/dev/null
    rm -rf /tmp/* 2>/dev/null
    
    echo -e "\e[1;32m✔ Setup Complete!\e[0m"
    echo -e "\e[1;36mNode Version:\e[0m $(node -v)"
    echo -e "\e[1;36mNPM Version:\e[0m $(npm -v)"
    echo -e "\e[1;32m▶ Running Codex...\e[0m"
    codex
}

function dpy() {
    echo -e "\n\e[1;36m🐍 Setting up Python, Pip & Virtualenv...\e[0m"
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
    
    # 🧹 RAM বাঁচানোর জন্য APT এর ক্যাশ ফাইল ডিলিট করা হচ্ছে
    echo -e "\e[1;35m🧹 Cleaning up apt cache to free RAM...\e[0m"
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    
    echo -e "\e[1;32m✔ Python environment is ready!\e[0m"
    echo -e "\e[1;36mPython Version:\e[0m $(python3 --version 2>&1)"
    echo -e "\e[1;36mPip Version:\e[0m $(pip3 --version 2>&1)"
}

function dgo() {
    echo -e "\n\e[1;36m🐹 Installing Golang...\e[0m"
    sudo apt update && sudo apt install -y golang
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
    echo -e "\e[1;32m✔ Go installed successfully!\e[0m"
    go version
}

function djava() {
    echo -e "\n\e[1;36m☕ Installing Java 17 LTS...\e[0m"
    sudo apt update && sudo apt install -y openjdk-17-jdk openjdk-17-jre
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
    echo -e "\e[1;32m✔ Java installed successfully!\e[0m"
    java -version
}

# ==========================================
# 📊 RAM USAGE BREAKDOWN FUNCTION (UPDATED UI)
# ==========================================
function ramtop() {
    echo -e "\n\e[1;36m📊 RAM Usage Breakdown (Top 15 Processes)\e[0m"
    echo -e "\e[90m─────────────────────────────────────────────────────────────────\e[0m"
    printf "  \e[1;33m%-7s │ %-8s │ %-6s │ %-9s │ %s\e[0m\n" "PID" "USER" "MEM%" "USED" "COMMAND"
    echo -e "\e[90m─────────────────────────────────────────────────────────────────\e[0m"
    ps -eo pid,user,%mem,rss,comm --sort=-rss | awk 'NR>1 {
        if($4>1024) { used = int($4/1024) " MB"; col="\e[1;31m"; }
        else { used = $4 " KB"; col="\e[1;33m"; }
        printf "  \e[1;37m%-7s\e[0m │ \e[1;32m%-8s\e[0m │ \e[1;36m%-6s\e[0m │ %s%-9s\e[0m │ \e[37m%s\e[0m\n", $1, substr($2,1,8), $3"%", col, used, $5
    }' | head -n 15
    echo -e "\e[90m─────────────────────────────────────────────────────────────────\e[0m\n"
}
alias ram='ramtop'

# ==========================================
# 📊 UI & DASHBOARD FUNCTIONS (ACCURATE FOR RAILWAY)
# ==========================================

function custom_motd() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2); KERNEL_VERSION=$(uname -r); ARCH=$(uname -m)
    CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//'); [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown Virtual CPU"
    
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
    if [ -n "$UPTIME_SEC" ] && [[ "$UPTIME_SEC" =~ ^[0-9]+$ ]]; then d=$((UPTIME_SEC / 86400)); h=$(( (UPTIME_SEC % 86400) / 3600 )); m=$(( (UPTIME_SEC % 3600) / 60 )); if [ $d -gt 0 ]; then MY_UPTIME="${d} days, ${h} hours, ${m} mins"; elif [ $h -gt 0 ]; then MY_UPTIME="${h} hours, ${m} mins"; else MY_UPTIME="${m} mins"; fi; else MY_UPTIME="Just started"; fi

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
    C_C="\e[36m"; C_G="\e[90m"; C_W="\e[1;37m"; C_R="\e[0m"
    echo -e "\n${C_W}▶ SYSTEM MONITOR (Container Stats Only)${C_R}\n${C_G}------------------------------------------------------------${C_R}"
    print_row() { echo -e " $1   ${C_W}$(printf "%-5s" "$2")${C_R} ${C_G}::${C_R}  ${C_C}$(printf "%-13s" "$3")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-13s" "$4")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-14s" "$5")${C_R}"; }
    
    # 1. RAM (Fully matched with Railway cgroups usage_in_bytes / memory.current)
    if [ -f /sys/fs/cgroup/memory.current ]; then
        RAM_USED_BYTES=$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 0)
        RAM_MAX_BYTES=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "max")
    elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
        RAM_USED_BYTES=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo 0)
        RAM_MAX_BYTES=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "max")
    else
        RAM_USED_BYTES=0
        RAM_MAX_BYTES="max"
    fi

    if [[ "$RAM_USED_BYTES" =~ ^[0-9]+$ ]]; then
        RAM_USED_MB=$((RAM_USED_BYTES / 1024 / 1024))
    else
        RAM_USED_MB=$(( $(ps -eo rss | awk 'NR>1 {sum+=$1} END {print sum}') / 1024 ))
    fi

    if [[ "$RAM_MAX_BYTES" =~ ^[0-9]+$ ]] && [ "$RAM_MAX_BYTES" -gt 0 ]; then
        RAM_MAX_MB=$((RAM_MAX_BYTES / 1024 / 1024))
        RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB))
        [ "$RAM_FREE_MB" -lt 0 ] && RAM_FREE_MB=0
        R1="${RAM_MAX_MB}MB Max"
        R2="${RAM_USED_MB}MB Used"
        R3="${RAM_FREE_MB}MB Free"
    else
        R1="953MB Max" # Railway Trial Default Fallback
        R2="${RAM_USED_MB}MB Used"
        R3="$((953 - RAM_USED_MB))MB Free"
    fi
    
    # 2. CPU (Calculating exact vCPU usage based on 0.5s window like Railway)
    if [ -f /sys/fs/cgroup/cpu.stat ]; then
        U1=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
        sleep 0.5
        U2=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
        # Delta over 500,000 microseconds gives exact vCPU count
        VCPU_USED=$(awk -v u1="$U1" -v u2="$U2" 'BEGIN { val=(u2-u1)/500000; if(val<0) val=0; printf "%.2f", val }')
    elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
        U1=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
        sleep 0.5
        U2=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
        VCPU_USED=$(awk -v u1="$U1" -v u2="$U2" 'BEGIN { val=(u2-u1)/500000000; if(val<0) val=0; printf "%.2f", val }')
    else
        VCPU_USED=$(ps -eo %cpu | awk 'NR>1 {sum+=$1} END {printf "%.2f", sum/100}')
    fi
    
    [ -z "$VCPU_USED" ] && VCPU_USED="0.00"
    
    C1="2.0 vCPU Max"
    C2="${VCPU_USED} vCPU"
    CPU_PCT=$(awk -v v="$VCPU_USED" 'BEGIN { printf "%.1f%%", (v/2)*100 }')
    C3="(${CPU_PCT} Used)"

    # 3. DISK (Calculating exactly how much disk space files inside the container are using)
    D_USED=$(du -sh --exclude=/proc --exclude=/sys --exclude=/dev / 2>/dev/null | awk '{print $1}')
    [ -z "$D_USED" ] && D_USED="0B"
    D1="Unlimited"; D2="${D_USED} Used"; D3="Container Only"
    
    # 4. FILES (Home Directory size)
    HOME_USAGE=$(du -sh ~ 2>/dev/null | awk '{print $1}')
    F1="---"; F2="${HOME_USAGE} Used"; F3="/home/$USER"
    
    print_row "❖" "RAM" "$R1" "$R2" "$R3"; print_row "⚙" "CPU" "$C1" "$C2" "$C3"; print_row "⛁" "DISK" "$D1" "$D2" "$D3"; print_row "▣" "FILES" "$F1" "$F2" "$F3"
    echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# কানেক্ট ফাংশন (cc) এবং (cs) [আপডেট করা হয়েছে: Tailscale এখন পুরোপুরি ব্যাকগ্রাউন্ডে চলবে]
function cc() {
    if pgrep -x "tailscaled" > /dev/null; then echo -e "\e[1;33mℹ Tailscale daemon is running.\e[0m"
    else echo -e "\e[1;33m⌛ Starting Tailscale in background...\e[0m"; nohup sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 & sleep 3; fi

    TS_KEY_FILE="$HOME/.ts_auth_key"; TS_KEY=""
    if [ -f "$TS_KEY_FILE" ]; then
        echo -e "\n\e[1;36m🔑 Previous Key found!\e[0m\n  \e[1;32m1) Use previous Key\e[0m\n  \e[1;33m2) Enter new Key\e[0m"; read -p "Option [1/2]: " OPTION
        if [ "$OPTION" == "1" ]; then TS_KEY=$(cat "$TS_KEY_FILE"); elif [ "$OPTION" == "2" ]; then read -p "New Key: " TS_KEY; [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"; else return 1; fi
    else
        echo -e "\e[1;36m"; read -p "Enter Tailscale Auth Key: " TS_KEY; echo -e "\e[0m"; [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
    fi
    [ -z "$TS_KEY" ] && return 1
    sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix
    if [ $? -eq 0 ]; then echo -e "\n\e[1;32m✔ Success! Phoenix is online.\e[0m\n"; else echo -e "\n\e[1;31m✘ Failed.\e[0m\n"; fi
}
function cs() { sudo tailscale logout 2>/dev/null; sudo tailscale down 2>/dev/null; sudo pkill -f tailscaled; echo -e "\e[1;32m✔ Tailscale stopped.\e[0m\n"; }

# --- 🚀 CLEAN LOGIN SCREEN ---
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;33m🔥 Quick Actions:\e[0m"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "cc" "Connect VPN"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "ram" "Detailed RAM Info"
    printf "   \e[1;36m%-10s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View ALL Shortcuts ⚡"
fi
EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc && \
    cat /tmp/setup.sh >> /root/.bashrc && \
    rm /tmp/setup.sh

# ৩. স্টার্টআপ স্ক্রিপ্ট
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e
/usr/sbin/sshd
tail -f /dev/null
SH

RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /root
EXPOSE 22
CMD ["/start.sh"]
