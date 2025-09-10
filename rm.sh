#!/bin/bash

# 批量停止并删除Docker容器脚本
# 作者: AI助手
# 功能: 根据关键词和数字范围交互式停止并删除容器

set -e  # 遇到错误立即退出

# 默认值设置
DEFAULT_KEYWORD="psyduck"
START_NUM=""
END_NUM=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo "使用方法:"
    echo "  此脚本将帮助您批量停止并删除Docker容器"
    echo "  您可以指定:"
    echo "  - 容器名称关键词 (如: psyduck)"
    echo "  - 起始数字 (如: 1)"
    echo "  - 结束数字 (如: 5)"
    echo "  将处理名称匹配 {关键词}{数字} 格式的容器"
    echo "  操作流程: 先停止容器 -> 再删除容器"
    echo ""
}

# 检查Docker是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装或未在PATH中找到!"
        exit 1
    fi
}

# 获取用户输入
get_user_input() {
    show_usage
    
    # 获取关键词
    read -p "请输入容器名称关键词 [默认: ${DEFAULT_KEYWORD}]: " keyword
    KEYWORD=${keyword:-$DEFAULT_KEYWORD}
    
    # 获取起始数字
    while true; do
        read -p "请输入起始数字 (必须为整数): " start_num
        if [[ "$start_num" =~ ^[0-9]+$ ]]; then
            START_NUM=$start_num
            break
        else
            print_error "请输入有效的整数!"
        fi
    done
    
    # 获取结束数字
    while true; do
        read -p "请输入结束数字 (必须为整数且大于等于起始数字): " end_num
        if [[ "$end_num" =~ ^[0-9]+$ ]] && [ "$end_num" -ge "$START_NUM" ]; then
            END_NUM=$end_num
            break
        else
            print_error "请输入有效的整数且不能小于起始数字!"
        fi
    done
}

# 预览要处理的容器
preview_containers() {
    print_info "预览匹配的容器:"
    echo "========================================"
    
    local count=0
    for ((i=START_NUM; i<=END_NUM; i++)); do
        container_name="${KEYWORD}${i}"
        container_id=$(docker ps -a --filter "name=^/${container_name}$" --format "{{.ID}}" 2>/dev/null || true)
        
        if [ ! -z "$container_id" ]; then
            container_status=$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
            echo "✅ 找到: ${container_name} (ID: ${container_id:0:12}, 状态: ${container_status})"
            count=$((count + 1))
        else
            echo "❌ 未找到: ${container_name}"
        fi
    done
    
    echo "========================================"
    if [ "$count" -eq 0 ]; then
        print_warning "没有找到任何匹配的容器!"
        return 1
    else
        print_info "总共找到 ${count} 个匹配的容器"
        return 0
    fi
}

# 确认操作
confirm_operation() {
    echo ""
    print_warning "⚠️  警告: 此操作将先停止再删除上述容器!"
    read -p "是否确认执行? (y/N): " confirm
    
    case "$confirm" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            print_info "操作已取消"
            exit 0
            ;;
    esac
}

# 停止容器
stop_containers() {
    local stopped_count=0
    local error_count=0
    
    print_info "开始停止容器..."
    echo "========================================"
    
    for ((i=START_NUM; i<=END_NUM; i++)); do
        container_name="${KEYWORD}${i}"
        container_id=$(docker ps -a --filter "name=^/${container_name}$" --format "{{.ID}}" 2>/dev/null || true)
        
        if [ ! -z "$container_id" ]; then
            container_status=$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
            
            # 只停止运行中的容器
            if [ "$container_status" = "running" ]; then
                echo -n "正在停止 ${container_name}..."
                if docker stop "$container_id" > /dev/null 2>&1; then
                    echo -e " ${GREEN}成功${NC}"
                    stopped_count=$((stopped_count + 1))
                else
                    echo -e " ${RED}失败${NC}"
                    error_count=$((error_count + 1))
                fi
            else
                echo "ℹ️  跳过停止 ${container_name} (状态: ${container_status})"
            fi
        fi
    done
    
    echo "========================================"
    
    if [ "$error_count" -eq 0 ]; then
        if [ "$stopped_count" -gt 0 ]; then
            print_success "停止完成! 成功停止 ${stopped_count} 个容器"
        else
            print_info "没有需要停止的运行中容器"
        fi
    else
        print_warning "停止完成! 成功: ${stopped_count}, 失败: ${error_count}"
    fi
    
    # 等待一段时间确保容器完全停止
    if [ "$stopped_count" -gt 0 ]; then
        print_info "等待容器完全停止..."
        sleep 2
    fi
}

# 删除容器
delete_containers() {
    local deleted_count=0
    local error_count=0
    
    print_info "开始删除容器..."
    echo "========================================"
    
    for ((i=START_NUM; i<=END_NUM; i++)); do
        container_name="${KEYWORD}${i}"
        container_id=$(docker ps -a --filter "name=^/${container_name}$" --format "{{.ID}}" 2>/dev/null || true)
        
        if [ ! -z "$container_id" ]; then
            echo -n "正在删除 ${container_name}..."
            if docker rm "$container_id" > /dev/null 2>&1; then
                echo -e " ${GREEN}成功${NC}"
                deleted_count=$((deleted_count + 1))
            else
                echo -e " ${RED}失败${NC}"
                error_count=$((error_count + 1))
            fi
        fi
    done
    
    echo "========================================"
    
    if [ "$error_count" -eq 0 ]; then
        print_success "删除完成! 成功删除 ${deleted_count} 个容器"
    else
        print_warning "删除完成! 成功: ${deleted_count}, 失败: ${error_count}"
    fi
}

# 主函数
main() {
    print_info "Docker 容器批量停止并删除工具"
    echo "----------------------------------------"
    
    # 检查Docker
    check_docker
    
    # 获取用户输入
    get_user_input
    
    # 显示用户选择
    echo ""
    print_info "您的选择:"
    echo "  关键词: ${KEYWORD}"
    echo "  数字范围: ${START_NUM} - ${END_NUM}"
    echo "  将匹配: ${KEYWORD}${START_NUM}, ${KEYWORD}$((START_NUM+1)), ..., ${KEYWORD}${END_NUM}"
    echo ""
    
    # 预览容器
    if ! preview_containers; then
        exit 0
    fi
    
    # 确认操作
    confirm_operation
    
    # 先停止容器
    stop_containers
    
    # 再删除容器
    delete_containers
}

# 运行主函数
main "$@"
