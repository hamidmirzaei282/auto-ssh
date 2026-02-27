#!/bin/bash

# --- Auto-setup Alias ---
if ! grep -q "alias menu=" ~/.bashrc; then
    echo "alias menu='~/menu.sh'" >> ~/.bashrc
    export PATH=$PATH:~
    alias menu='~/menu.sh'
fi

# Install sshpass if missing
if ! command -v sshpass &> /dev/null; then
    sudo apt update && sudo apt install sshpass -y
fi

show_menu() {
    clear
    echo "===================================="
    echo "        TUNNEL MANAGEMENT MENU        "
    echo "===================================="
    echo "1) Optimize Network (Enable BBR)"
    echo "2) Set Auto-Maintenance (Cron Jobs)"
    echo "3) Open Tunnel Ports (UFW Firewall)"
    echo "4) Install AutoSSH Requirements"
    echo "5) Keys (Make or Show SSH Keys)"
    echo "6) Auto-Copy SSH Key to Remote Server"
    echo "7) Setup Tunnel Service (Manual Edit)"
    echo "8) Start/Restart Tunnel Service"
    echo "9) Show Tunnel Status"
    echo "0) Exit"
    echo "===================================="
    read -p "Select an option: " main_opt
}

key_menu() {
    clear
    echo "--- KEY MANAGEMENT ---"
    echo "1) Make Key (ssh-keygen)"
    echo "2) Show Key (cat id_rsa.pub)"
    echo "3) Back to Main Menu"
    read -p "Select an option: " key_opt
    case $key_opt in
        1) ssh-keygen -t rsa ;;
        2) cat ~/.ssh/id_rsa.pub ; echo "" ; read -p "Press Enter to continue..." ;;
        3) return ;;
    esac
}

while true; do
    show_menu
    case $main_opt in
        1)
            echo "Enabling BBR permanently..."
            if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
                echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p
                echo "BBR added and activated."
            else
                echo "BBR is already configured."
            fi
            read -p "Press Enter to continue..."
            ;;
        2)
            echo "Setting up Cron Jobs..."
            (crontab -l 2>/dev/null | grep -v "journalctl" | grep -v "restart tunnel"; 
             echo "0 */2 * * * /usr/bin/journalctl --vacuum-time=1h";
             echo "0 4 * * * /usr/bin/systemctl restart tunnel") | crontab -
            echo "Cron jobs set successfully."
            read -p "Press Enter to continue..."
            ;;
        3)
            echo "Opening Ports..."
            sudo ufw allow 22,1212,2083,2087,8443,2053,4044,3033/tcp
            sudo ufw reload
            echo "Ports opened."
            read -p "Press Enter to continue..."
            ;;
        4)
            sudo apt update && sudo apt install autossh -y
            read -p "Done. Press Enter..."
            ;;
        5) key_menu ;;
        6)
            read -p "Enter Remote IP: " r_ip
            read -p "Enter Remote SSH Port (default 22): " r_port
            r_port=${r_port:-22}
            read -s -p "Enter Remote Password: " r_pass
            echo -e "\nCopying key..."
            sshpass -p "$r_pass" ssh-copy-id -o StrictHostKeyChecking=no -p "$r_port" "root@$r_ip"
            read -p "Press Enter to continue..."
            ;;
        7)
            echo "--- Manual Tunnel Configuration ---"
            echo "Opening service file with nano..."
            echo "Paste your service configuration, then press Ctrl+O, Enter, and Ctrl+X."
            sleep 3
            SERVICE_FILE="/etc/systemd/system/tunnel.service"
            sudo nano $SERVICE_FILE
            echo "Service file updated."
            read -p "Press Enter to continue..."
            ;;
        8)
            sudo systemctl daemon-reload
            sudo pkill -f autossh
            sudo systemctl restart tunnel
            echo "Tunnel Reloaded and Restarted."
            sleep 2
            sudo systemctl status tunnel
            read -p "Press Enter to continue..."
            ;;
        9)
            sudo systemctl status tunnel
            read -p "Press Enter to continue..."
            ;;
        0) break ;;
        *) echo "Invalid option!" ; sleep 1 ;;
    esac
done
