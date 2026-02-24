#!/bin/bash
# =================================================================
# 🏆 BEST FLASH EVER v2.1 - SECURE CHECK, SMART FIND & AUTO UNZIP
# =================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Biến lưu trạng thái pass/fail
CHECK_IMAGE=0
CHECK_BOOT=0
CHECK_DRIVER=0

clear
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}🚀 YOCTO SECURE FLASH - QUY TRÌNH KÉP & SMART FLASH${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Script này cần quyền root để flash: sudo ./best_flash_ever.sh${NC}"
    exit 1
fi

# Hàm hỏi người dùng (Challenge)
verify_step() {
    local step_name=$1
    local expected_key_prefix=$2
    local warning_msg=$3

    echo -e "\n${YELLOW}--- BƯỚC KIỂM TRA: $step_name ---${NC}"
    echo -e "❓ Bạn có đồng ý bỏ qua kiểm tra tự động của files_check.sh không? (y/n)"
    read -p "   Lựa chọn: " AGREE

    if [[ "$AGREE" =~ ^[Yy]$ ]]; then
        return 0 # User tin tưởng, pass luôn
    else
        echo -e "${RED}⚠️  CHẾ ĐỘ KIỂM TRA CHUYÊN SÂU KÍCH HOẠT${NC}"
        echo -e "   Hãy chạy ./files_check.sh ở terminal khác."
        echo -e "   Copy dòng chứa ${BLUE}$expected_key_prefix${NC} và dán vào đây."
        read -p "   🖊️  PASTE KEY HERE: " USER_INPUT

        if [[ "$USER_INPUT" == *"$expected_key_prefix"* ]]; then
            # Kiểm tra logic của key (Ví dụ đơn giản)
            if [[ "$USER_INPUT" == *"MISSING"* ]] || [[ "$USER_INPUT" == *"NOT_FOUND"* ]] || [[ "$USER_INPUT" == *"OUTDATED"* ]]; then
                 echo -e "${RED}❌ PHÁT HIỆN LỖI TỪ KEY: $warning_msg${NC}"
                 read -p "   Bạn có chắc chắn muốn tiếp tục dù có lỗi này? (yes/no): " FORCE
                 if [ "$FORCE" != "yes" ]; then return 1; fi
            else
                 echo -e "${GREEN}✅ Key hợp lệ!${NC}"
            fi
            return 0
        else
            echo -e "${RED}❌ Key không khớp hoặc sai định dạng!${NC}"
            return 1
        fi
    fi
}

# --- BẮT ĐẦU QUY TRÌNH ---

# 1. Image Check
if verify_step "IMAGE INTEGRITY" "[KEY-IMAGE]" "File ảnh bị lỗi hoặc không tồn tại."; then
    CHECK_IMAGE=1
else
    echo -e "${RED}⛔ Dừng tại bước Image Check.${NC}"; exit 1
fi

# 2. Boot Config Check
if verify_step "BOOT CONFIGURATION" "[KEY-BOOT]" "Thiếu cấu hình Boot (config.txt/UART). Pi có thể không lên hình."; then
    CHECK_BOOT=1
else
    CHECK_BOOT=0 # Vẫn cho đi tiếp nhưng ghi nhận fail
fi

# 3. Driver Sync Check
if verify_step "DRIVER SYNCHRONIZATION" "[KEY-DRIVER]" "Driver không đồng bộ hoặc chưa được gói vào Image."; then
    CHECK_DRIVER=1
else
    CHECK_DRIVER=0
fi

# --- HIỂN THỊ SƠ ĐỒ MEMORY ASCII ---
echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}🗺️  SƠ ĐỒ DỰ KIẾN SAU KHI FLASH${NC}"
echo -e "${BLUE}======================================================${NC}"

echo -e "
+-----------------[ THẺ NHỚ SD ]------------------+
| MBR |  PARTITION 1  |   PARTITION 2   |  TRỐNG  |
|     |  (BOOT - FAT) | (ROOTFS - EXT4) | (EXPAND)|
| 4MB |     ~64MB     |    ~IMAGE_SIZE  |   ...   |
|     | [config.txt]  | [/lib/modules/] |         |
|     | [kernel8.img] | [led_driver.ko] |         |
+-----+---------------+-----------------+---------+
"

# --- BẢNG TỔNG KẾT ---
echo -e "${YELLOW}📊 BẢNG TỔNG KẾT TRƯỚC KHI FLASH:${NC}"
echo "+----------------------+--------+"
echo "| TIÊU CHÍ             | KẾT QUẢ|"
echo "+----------------------+--------+"
if [ $CHECK_IMAGE -eq 1 ]; then echo -e "| Image Integrity      | ${GREEN}PASS${NC}   |"; else echo -e "| Image Integrity      | ${RED}FAIL${NC}   |"; fi
if [ $CHECK_BOOT -eq 1 ];  then echo -e "| Boot Config          | ${GREEN}PASS${NC}   |"; else echo -e "| Boot Config          | ${RED}WARN${NC}   |"; fi
if [ $CHECK_DRIVER -eq 1 ]; then echo -e "| Driver Sync          | ${GREEN}PASS${NC}   |"; else echo -e "| Driver Sync          | ${RED}WARN${NC}   |"; fi
echo "+----------------------+--------+"

if [ $CHECK_IMAGE -eq 0 ]; then
    echo -e "${RED}❌ KHÔNG THỂ FLASH VÌ IMAGE CHƯA ĐẠT YÊU CẦU.${NC}"
    exit 1
fi

# --- XÁC NHẬN CUỐI CÙNG ---
echo -e "\n⚠️  HÀNH ĐỘNG NÀY SẼ XÓA SẠCH DỮ LIỆU TRÊN THẺ NHỚ."
read -p "Gõ 'yes' để tiến hành FLASH ngay: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" == "yes" ]; then
    # ==========================
    # ĐOẠN CODE FLASH THÔNG MINH
    # ==========================
    echo -e "\n${GREEN}🚀 ĐANG TÌM KIẾM DỮ LIỆU ĐỂ FLASH...${NC}"
    
    # KẾ HOẠCH A: Tìm Image trong thư mục build (Ưu tiên số 1)
    DEPLOY_DIR="/home/chien/work/poky/build_rpi4/tmp/deploy/images/raspberrypi4-64"
    IMG=""
    if [ -d "$DEPLOY_DIR" ]; then
        IMG=$(find "$DEPLOY_DIR" -maxdepth 1 -name "*.rpi-sdimg" -not -name "*rootfs.rpi-sdimg" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
        if [ -z "$IMG" ]; then 
            IMG=$(find "$DEPLOY_DIR" -maxdepth 1 -name "*rootfs.rpi-sdimg" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
        fi
    fi
    
    # KẾ HOẠCH B: Nếu không tìm thấy ảnh mới, dùng file Backup trong Downloads
    if [ -z "$IMG" ]; then
        echo -e "${YELLOW}⚠️ Không tìm thấy ảnh mới trong thư mục build.${NC}"
        echo -e "${YELLOW}🔄 Đang chuyển sang sử dụng file Backup nén...${NC}"
        IMG="/home/chien/Downloads/backup_full_card_uboot_yocto.img.gz"
        
        # Kiểm tra xem file backup có tồn tại không
        if [ ! -f "$IMG" ]; then
            echo -e "${RED}❌ LỖI NGHIÊM TRỌNG: Không tìm thấy file ảnh mới và cũng không tìm thấy file Backup!${NC}"
            echo -e "Vui lòng kiểm tra lại đường dẫn: $IMG"
            exit 1
        fi
    fi
    
    # 2. Tìm thẻ nhớ (SD Card)
    echo "Đang tìm thẻ nhớ..."
    DISK=$(lsblk -d -o NAME,SIZE,TYPE,TRAN | grep "disk" | grep "usb" | awk '{print "/dev/" $1}' | head -n 1)
    
    if [ -z "$DISK" ]; then
        # Thử tìm mmcblk0 (nếu dùng đầu đọc thẻ gắn trong máy ảo)
        DISK=$(lsblk -d -o NAME,SIZE,TYPE | grep "mmcblk" | awk '{print "/dev/" $1}' | head -n 1)
    fi

    if [ -z "$DISK" ]; then
        echo -e "${RED}❌ Không tìm thấy thẻ nhớ! Hãy cắm thẻ vào.${NC}"
        exit 1
    fi

    echo -e "👉 Detected Image: ${CYAN}$IMG${NC}"
    echo -e "👉 Detected Device: ${YELLOW}$DISK${NC}"
    
    # 3. Lệnh Flash thật (Tự nhận diện file nén hoặc file raw)
    umount ${DISK}* 2>/dev/null || true
    
    if [[ "$IMG" == *.gz ]]; then
        echo -e "📦 Đang giải nén và flash trực tiếp từ file Backup (.gz)... (Sẽ mất vài phút)"
        # Dùng zcat xuất luồng dữ liệu, cho qua pv để xem tiến trình, rồi đẩy vào dd
        zcat "$IMG" | pv | dd of="$DISK" bs=4M conv=fsync status=none
    else
        echo -e "💿 Đang flash file raw (.rpi-sdimg)..."
        pv "$IMG" | dd of="$DISK" bs=4M conv=fsync status=none
    fi
    
    sync
    echo -e "\n${GREEN}🎉 FLASH THÀNH CÔNG! BẠN CÓ THỂ RÚT THẺ VÀ CẮM VÀO PI.${NC}"
else
    echo -e "${YELLOW}🚫 Đã hủy flash theo yêu cầu người dùng.${NC}"
fi
