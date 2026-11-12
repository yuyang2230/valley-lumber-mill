@echo off
rem 一键发布《盐线：山谷·伐木场》到 GitHub 新仓库（与船厂版仓库完全独立）
rem 首次运行会弹出 GitHub 授权窗口；若 github.com:443 被墙，改用 work-tools/push-via-api.mjs + token
chcp 65001 >nul
cd /d "%~dp0"
echo === 提交本地改动 ===
git add -A
git commit -m "盐线：山谷·伐木场 — 4人猛攻小队故事线（全程序化生成，全中文含语音）" || echo (没有新改动)
echo === 推送 ===
git push -u origin main
if errorlevel 1 (
  echo.
  echo 推送失败：多半是 github.com 被墙。请走 API 通道：
  echo   node C:\Users\Administrator\Desktop\youxi\work-tools\push-via-api.mjs <你的token>
  echo   (该脚本默认目标仓库 valley-lumber-mill；如改了仓库名请同步脚本里的 REPO 常量)
  pause
  exit /b 1
)
echo.
echo 完成！仓库: https://github.com/yuyang2230/valley-lumber-mill
echo 开启 Pages: Settings -^> Pages -^> Branch 选 main
pause
