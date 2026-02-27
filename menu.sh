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
    echo "       TUNNEL MANAGEMENT MENU       "
    echo "===================================="
    echo "1) Optimize Network (Enable BBR)"
    echo "2) Set Auto-Maintenance (Cron Jobs)"
    echo "3) Open Tunnel Ports (UFW Firewall)"
    echo "4) Install AutoSSH Requirements"
    echo "5) Keys (Make or Show SSH Keys)"
    echo "6) Auto-Copy SSH Key to Remote Server"
    echo "7) Setup Tunnel Service (Auto-Configure)"
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
                echo "BBR added and activated permanently."
            else
                echo "BBR is already configured."
            fi
            read -p "Press Enter to continue..."
            ;;
        2)
            echo "Setting up Cron Jobs for Maintenance..."
            (crontab -l 2>/dev/null | grep -v "journalctl" | grep -v "restart tunnel"; 
             echo "0 */2 * * * /usr/bin/journalctl --vacuum-time=1h";
             echo "0 4 * * * /usr/bin/systemctl restart tunnel") | crontab -
            echo "Cron jobs (Log Clean & 4AM Restart) set successfully."
            read -p "Press Enter to continue..."
            ;;
        3)
            echo "Opening Ports: 1212, 2083, 2087, 8443, 2053, 4044, 3033..."
            sudo ufw allow 1212,2083,2087,8443,2053,4044,3033/tcp
            sudo ufw reload
            echo "Ports opened and Firewall reloaded."
            read -p "Press Enter to continue..."
            ;;
        4)
            sudo apt update && sudo apt install autossh -y
            read -p "Installation done. Press Enter..."
            ;;
        5) key_menu ;;
        6)
            read -p "Enter Remote (Foreign) IP: " r_ip
            read -p "Enter Remote SSH Port (default 22): " r_port
            r_port=${r_port:-22}
            read -s -p "Enter Remote Root Password: " r_pass
            echo ""
            echo "Attempting to copy key..."
            sshpass -p "$r_pass" ssh-copy-id -o StrictHostKeyChecking=no -p "$r_port" "root@$r_ip"
            if [ $? -eq 0 ]; then
                echo "Success! Key copied."
            else
                echo "Failed! Check IP/Port/Password."
            fi
            read -p "Press Enter to continue..."
            ;;
        7)
            echo "--- Tunnel Configuration Wizard ---"
            read -p "Enter Remote (Foreign) IP: " remote_ip
            read -p "Enter Remote SSH Port (e.g. 22): " ssh_port
            read -p "Enter Tunnel Ports (e.g. 8443,2087,2053): " t_ports
            
            SERVICE_FILE="/etc/systemd/system/tunnel.service"
            sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=AutoSSH Tunnel Service
After=network.target

[Service]
Environment=\"AUTOSSH_GATETIME=0\"
ExecStart=/usr/bin/autossh -M 0 -o \"ServerAliveInterval 30\" -o \"ServerAliveCountMax 3\" -NR *:${t_ports}:localhost:${t_ports} root@${remote_ip} -p ${ssh_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"
            echo "Service file created automatically for IP $remote_ip and Ports $t_ports"
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
