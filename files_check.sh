#!/bin/bash
# =================================================================
# 🕵️ FILES CHECKER - TRÌNH THẨM ĐỊNH YOCTO NÂNG CAO
# =================================================================
# Chức năng:
# 1. Kiểm tra Meta Layers & Recipe
# 2. Phân tích nội dung file Image (.rpi-sdimg)
# 3. Xuất mã xác thực (Verification Codes) để dùng cho best_flash_ever.sh
# =================================================================

DEPLOY_DIR="./build_rpi4/tmp/deploy/images/raspberrypi4-64"
LAYERS_CONF="./build_rpi4/conf/bblayers.conf"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}🔍 YOCTO DEEP INSPECTION REPORT${NC}"
echo -e "${CYAN}======================================================${NC}"

# --- PHẦN 1: KIỂM TRA MÔI TRƯỜNG & META LAYERS ---
echo -e "\n${YELLOW}[1] KIỂM TRA META LAYERS & RECIPES${NC}"

# Tìm đường dẫn meta-raspberrypi trong bblayers.conf
META_RPI_PATH=$(grep "meta-raspberrypi" "$LAYERS_CONF" | awk '{print $1}' | tr -d '"')

if [ -n "$META_RPI_PATH" ]; then
    echo -e "✅ Layer meta-raspberrypi: ${GREEN}DETECTED${NC}"
    echo -e "   📂 Path: $META_RPI_PATH"
    
    # Kiểm tra recipe config kernel
    KERNEL_RECIPE="$META_RPI_PATH/recipes-kernel/linux/linux-raspberrypi_5.4.bb" 
    # (Lưu ý: Tên file .bb có thể khác tùy phiên bản, đây là check mẫu)
    echo -e "   ℹ️  Gợi ý: Nếu cần sửa Kernel, hãy xem tại: $META_RPI_PATH/recipes-kernel/linux/"
else
    echo -e "${RED}❌ LỖI NGHIÊM TRỌNG: Không tìm thấy meta-raspberrypi trong bblayers.conf!${NC}"
    echo -e "   👉 Hãy thêm layer này bằng lệnh: bitbake-layers add-layer ../meta-raspberrypi"
fi

# Check Yocto Version (Dựa vào branch của poky)
YOCTO_VER=$(cd ../poky && git branch --show-current 2>/dev/null || echo "Unknown")
echo -e "   🏷️  Yocto Branch: ${CYAN}$YOCTO_VER${NC}"

# --- PHẦN 2: TÌM VÀ PHÂN TÍCH IMAGE MỚI NHẤT ---
echo -e "\n${YELLOW}[2] PHÂN TÍCH FILE ẢNH (.rpi-sdimg)${NC}"

IMAGE_FILE=$(find "$DEPLOY_DIR" -maxdepth 1 -name "*.rpi-sdimg" -not -name "*rootfs.rpi-sdimg" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
# Nếu không tìm thấy file symlink ngắn, lấy file dài
if [ -z "$IMAGE_FILE" ]; then
    IMAGE_FILE=$(find "$DEPLOY_DIR" -maxdepth 1 -name "*rootfs.rpi-sdimg" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
fi

if [ -f "$IMAGE_FILE" ]; then
    echo -e "✅ Image File: ${GREEN}$(basename "$IMAGE_FILE")${NC}"
    
    # Check ngày giờ build
    BUILD_TIME=$(stat -c %y "$IMAGE_FILE")
    echo -e "   🕒 Build Time: $BUILD_TIME"
    
    # Check kích thước
    SIZE=$(stat -c %s "$IMAGE_FILE")
    echo -e "   💾 Size: $((SIZE / 1024 / 1024)) MB"

    # --- TẠO MÃ XÁC THỰC IMAGE (Dùng file size làm key đơn giản) ---
    echo -e "   🔑 ${CYAN}[KEY-IMAGE]: SIZE_$SIZE${NC}" 

    # Check phân vùng bên trong bằng fdisk
    echo -e "   🔍 Cấu trúc phân vùng:"
    /sbin/fdisk -l "$IMAGE_FILE" | grep "^$IMAGE_FILE" | awk '{print "      - " $1 " | " $6 " | " $7}'
    
    # Kiểm tra xem có đủ 2 phân vùng không
    PART_COUNT=$(/sbin/fdisk -l "$IMAGE_FILE" | grep "^$IMAGE_FILE" | wc -l)
    if [ "$PART_COUNT" -ge 2 ]; then
        echo -e "   ✅ Phân vùng: ${GREEN}HỢP LỆ (Có Boot & Rootfs)${NC}"
    else
        echo -e "   ${RED}❌ LỖI: File ảnh bị hỏng cấu trúc phân vùng!${NC}"
    fi

else
    echo -e "${RED}❌ KHÔNG TÌM THẤY FILE .rpi-sdimg NÀO!${NC}"
    echo "   👉 Bạn đã chạy 'bitbake core-image-minimal' chưa?"
    exit 1
fi

# --- PHẦN 3: KIỂM TRA NỘI DUNG BOOT (CONFIG/CMDLINE) ---
echo -e "\n${YELLOW}[3] KIỂM TRA NỘI DUNG BOOT CONFIG${NC}"

# Logic: Config.txt thường nằm trong deploy, nếu không có thì nó nằm trong Image.
CONFIG_FILE="$DEPLOY_DIR/config.txt"
CMDLINE_FILE="$DEPLOY_DIR/cmdline.txt"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "✅ Tìm thấy config.txt trong Deploy:"
    echo -e "${CYAN}   --- CONTENT PREVIEW ---${NC}"
    grep -E "uart|gpu|dtparam" "$CONFIG_FILE" | head -n 5
    echo -e "${CYAN}   -----------------------${NC}"
    # Tạo mã xác thực boot
    echo -e "   🔑 ${CYAN}[KEY-BOOT]: CONFIG_FOUND${NC}"
else
    echo -e "⚠️  Không thấy config.txt rời. Đang kiểm tra trong Image..."
    # Hack: Dùng grep binary để tìm chuỗi trong file ảnh (vì không mount được nếu ko có sudo)
    if grep -q "enable_uart" "$IMAGE_FILE"; then
         echo -e "✅ Phát hiện chuỗi 'enable_uart' bên trong file ảnh (.rpi-sdimg)."
         echo -e "   👉 config.txt đã được đóng gói vào Partition 1."
         echo -e "   🔑 ${CYAN}[KEY-BOOT]: EMBEDDED_OK${NC}"
    else
         echo -e "${RED}❌ CẢNH BÁO: Không tìm thấy dấu hiệu cấu hình UART trong file ảnh!${NC}"
         echo -e "   🔑 ${CYAN}[KEY-BOOT]: MISSING${NC}"
    fi
fi

# --- PHẦN 4: KIỂM TRA LINH HỒN (DRIVER) ---
echo -e "\n${YELLOW}[4] KIỂM TRA CUSTOM DRIVER (LED-DRIVER)${NC}"
DRIVER_IN_DEPLOY=$(find "$DEPLOY_DIR" -name "modules-*.tgz")

if [ -n "$DRIVER_IN_DEPLOY" ]; then
    echo -e "✅ Tìm thấy gói Modules: $(basename "$DRIVER_IN_DEPLOY")"
    
    # Check kỹ file .ko
    LED_KO=$(find ./build_rpi4/tmp/work -name "led_driver.ko" | head -n 1)
    if [ -n "$LED_KO" ]; then
         TIME_KO=$(stat -c %y "$LED_KO")
         echo -e "   ✅ File .ko gốc: ${GREEN}FOUND${NC}"
         echo -e "   🕒 Thời gian build driver: $TIME_KO"
         
         # So sánh thời gian build driver và image
         IMG_EPOCH=$(stat -c %Y "$IMAGE_FILE")
         KO_EPOCH=$(stat -c %Y "$LED_KO")
         
         if [ "$KO_EPOCH" -gt "$IMG_EPOCH" ]; then
             echo -e "   ${RED}⚠️  CẢNH BÁO: Driver mới hơn Image! (Bạn build driver sau khi build image?)${NC}"
             echo -e "   👉 Cần chạy lại: bitbake core-image-minimal để gói driver mới vào image."
             echo -e "   🔑 ${CYAN}[KEY-DRIVER]: OUTDATED_IMAGE${NC}"
         else
             echo -e "   ✅ Đồng bộ thời gian: OK"
             echo -e "   🔑 ${CYAN}[KEY-DRIVER]: SYNC_OK${NC}"
         fi
    else
         echo -e "${RED}❌ KHÔNG TÌM THẤY FILE led_driver.ko TRONG THƯ MỤC WORK!${NC}"
         echo -e "   🔑 ${CYAN}[KEY-DRIVER]: NOT_FOUND${NC}"
    fi
else
    echo -e "${RED}❌ Không tìm thấy gói modules tgz!${NC}"
fi

echo -e "\n${CYAN}======================================================${NC}"
echo -e "📝 HƯỚNG DẪN TIẾP THEO:"
echo -e "Giữ terminal này mở. Chạy ${YELLOW}sudo ./best_flash_ever.sh${NC} ở terminal khác."
echo -e "Khi được hỏi, hãy copy các dòng ${CYAN}[KEY-...]${NC} ở trên và dán vào."
echo -e "${CYAN}======================================================${NC}"
