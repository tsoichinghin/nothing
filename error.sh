#!/bin/bash

ERROR_DIR="/root/error"

# 建立目錄確保安全
mkdir -p "$ERROR_DIR"

while true; do

    for txt_file in "$ERROR_DIR"/*.txt; do
        # 防止目錄為空時把 *.txt 當成字符串處理
        [ -e "$txt_file" ] || continue

        # 讀取裡面的標記內容（去掉可能的換行或空格）
        status=$(cat "$txt_file" | tr -d '[:space:]')

        if [ "$status" = "y" ]; then
            # 從文件名中提取出容器名稱 (例如從 /root/error/ip101.txt 提取出 ip101)
            container_name=$(basename "$txt_file" .txt)
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') 🚨 發現容器 $container_name 標記為 y，正在執行強制物理重啟..."
            
            # 執行 Docker 重啟
            docker restart "$container_name"
            
            # 🎯 絕殺：重啟後，立刻在宿主機把標記改回 n，等待下一輪輪詢
            printf "n" > "$txt_file"
            echo "✅ $container_name 重啟完成，標記已重置為 n。"
        fi

        sleep 1

    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') 完成一次巡邏，等待30秒..."

    sleep 30

done
