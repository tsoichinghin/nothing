#!/bin/bash

ERROR_DIR="/root/error"
IP_FILE="/root/ip.txt"

# 固定的矩陣環境變數
TM_TOKEN="Nwma6KuxfvF/jJUsBCtyl/3cHfIoEA8oxdBA7RkgKN0="
PS_CID="84Vb"
RP_EMAIL="tsoichinghin@gmail.com"
RP_API_KEY="a17ebebc-ad88-40ba-ba85-9eaee015e1f4"
VPS="wse3"

# 建立目錄確保安全
mkdir -p "$ERROR_DIR"

while true; do

    for txt_file in "$ERROR_DIR"/*.txt; do
        # 防止目錄為空時把 *.txt 當成字串處理
        [ -e "$txt_file" ] || continue

        # 讀取裡面的標記內容（去掉可能的換行或空格）
        status=$(cat "$txt_file" | tr -d '[:space:]')

        if [ "$status" = "y" ]; then
            # 1. 從檔名提取出容器名稱 (例如 ip101.txt -> ip101)
            container_name=$(basename "$txt_file" .txt)
            
            # 2. 提取出純數字編號 (例如 ip101 -> 101)
            number=$(echo "$container_name" | sed 's/[^0-9]//g')
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') 🚨 發現容器 $container_name 標記為 y，準備執行徹底重置（RM & RUN）..."

            # 3. 🎯 絕殺：根據 number 去 ip.txt 提取對應的那一行 (例如 number=1 提取第1行)
            if [ ! -f "$IP_FILE" ]; then
                echo "❌ [錯誤] 找不到 $IP_FILE，無法獲取代理資料，跳過此容器！"
                continue
            fi
            
            # 使用 sed 核心精準定位第 N 行
            line=$(sed -n "$number"p "$IP_FILE")
            
            if [ -z "$line" ]; then
                echo "❌ [錯誤] 在 $IP_FILE 找不到第 $number 行的資料，跳過此容器！"
                continue
            fi

            # 4. 解析該行的代理資料
            ip=$(echo "$line" | cut -d':' -f1)
            port=$(echo "$line" | cut -d':' -f2)
            username=$(echo "$line" | cut -d':' -f3)
            password=$(echo "$line" | cut -d':' -f4)

            # 5. 執行物理銷毀
            echo "🧹 正在強制刪除舊容器 $container_name..."
            docker rm -f "$container_name" >/dev/null 2>&1 || true
            
            # 6. 🚀 重新拉起全新網絡棧的容器
            echo "🚀 正在為第 $number 行代理重新運行全新的容器..."
            docker run -d \
                  --name "ip$number" \
                  --restart on-failure:10 \
                  --cap-add=NET_ADMIN \
                  -v /root/error:/error \
                  -e number="$number" \
                  -e PROXY_IP="$ip" \
                  -e PROXY_PORT="$port" \
                  -e PROXY_USER="$username" \
                  -e PROXY_PASSWORD="$password" \
                  -e TM_TOKEN="$TM_TOKEN" \
                  -e DEVICE_NAME="$VPS-$number" \
                  -e CID="$PS_CID" \
                  -e RP_EMAIL="$RP_EMAIL" \
                  -e RP_API_KEY="$RP_API_KEY" \
                  tsoichinghin/proxymix:latest
            
            # 7. 🎯 重置狀態標記文件為 n，等待下一輪
            printf "n" > "$txt_file"
            echo "✅ $container_name 已徹底重生，標記已重置為 n。"
        fi

        sleep 1
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') 完成一次巡邏，等待30秒..."
    sleep 30

done
