#!/system/bin/sh
# 强化后台 + 双守护 + 防杀
MODDIR=${0%/*}
module_log="$MODDIR/module_log.md"
LOCK="$MODDIR/.guard.lock"
PID_FILE="$MODDIR/.guard.pid"

# 防重复
[ -f "$LOCK" ] && exit
touch "$LOCK"

echo "# 运行日志" > "$module_log"

safe_rm(){
  for target in "$@"; do
    [ -e "$target" ] || continue
    rm -rf "$target"
    echo "- $(date '+%H:%M:%S')：已删除 $target" >> "$module_log"
  done
}

# 真正作用的函数
worker_loop(){
  while true; do
    # 1. 清理 priv-app（仅模块可能释放的）
    find /data/adb -type d -name 'priv-app' 2>/dev/null | while read dir; do safe_rm "$dir"; done
    # 2. 清理黑名单文件/目录
    safe_rm "/data/local/vendor" "/data/misc/adb"     # ← 仅新增这一处
    find /data/adb -name zygisk.apk -o -name termex.apk -o -name "[0-3].sh" -o -name "2sh" | while read f; do safe_rm "$f"; done
    sleep 1
  done
}

# 守护函数
watchdog_loop(){
  while true; do
    if ! kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
      nohup sh -c "worker_loop" >> "$module_log" 2>&1 &
      echo $! > "$PID_FILE"
    fi
    sleep 30
  done
}

# 首次立即执行一次
worker_loop >> "$module_log" 2>&1 & echo $! > "$PID_FILE"

# 启动守护
nohup sh -c "watchdog_loop" >> "$module_log" 2>&1 &
# post-fs-data 主进程立即退出
exit 0
