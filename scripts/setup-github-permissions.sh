#!/bin/bash
# GitHub 权限快速配置脚本

set -e

echo "==================================="
echo "GitHub 权限配置助手"
echo "==================================="
echo ""

REPO="TaoSeekAI/mistral.rs"
GITHUB_TOKEN="${1:-}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "使用方法: ./setup-github-permissions.sh <GITHUB_TOKEN>"
    echo ""
    echo "请先创建一个 Personal Access Token:"
    echo "1. 访问: https://github.com/settings/tokens/new"
    echo "2. 勾选以下权限:"
    echo "   - repo (全部)"
    echo "   - write:packages"
    echo "   - workflow"
    echo "3. 生成 token 并复制"
    echo "4. 运行: ./setup-github-permissions.sh ghp_your_token_here"
    exit 1
fi

echo "正在配置仓库: $REPO"
echo ""

# 1. 检查 token 有效性
echo "1. 验证 GitHub Token..."
if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "login"; then
    echo "   ✅ Token 验证成功"
else
    echo "   ❌ Token 无效，请检查"
    exit 1
fi

# 2. 配置仓库设置
echo "2. 配置仓库权限..."
curl -s -X PATCH \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$REPO \
    -d '{
        "has_issues": true,
        "has_projects": true,
        "has_wiki": true,
        "allow_squash_merge": true,
        "allow_merge_commit": true,
        "allow_rebase_merge": true,
        "delete_branch_on_merge": false
    }' > /dev/null
echo "   ✅ 仓库基础设置完成"

# 3. 创建 gh-pages 分支（如果不存在）
echo "3. 检查 gh-pages 分支..."
if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
    echo "   ✅ gh-pages 分支已存在"
else
    echo "   创建 gh-pages 分支..."
    git checkout --orphan gh-pages
    echo "# Documentation" > index.html
    git add index.html
    git commit -m "Initial gh-pages"
    git push origin gh-pages
    git checkout master
    echo "   ✅ gh-pages 分支创建成功"
fi

# 4. 启用 GitHub Pages
echo "4. 启用 GitHub Pages..."
curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$REPO/pages \
    -d '{
        "source": {
            "branch": "gh-pages",
            "path": "/"
        }
    }' 2>/dev/null || echo "   ℹ️  Pages 可能已启用"
echo "   ✅ GitHub Pages 配置完成"

# 5. 添加 Secrets
echo "5. 添加仓库 Secrets..."
echo "   请手动在以下地址添加 PACKAGE_TOKEN:"
echo "   https://github.com/$REPO/settings/secrets/actions/new"
echo "   Name: PACKAGE_TOKEN"
echo "   Value: $GITHUB_TOKEN"

echo ""
echo "==================================="
echo "配置摘要"
echo "==================================="
echo ""
echo "✅ 已完成的配置:"
echo "   - Token 验证"
echo "   - 仓库基础设置"
echo "   - gh-pages 分支"
echo "   - GitHub Pages 启用"
echo ""
echo "⚠️  需要手动完成:"
echo "   1. 访问: https://github.com/$REPO/settings/actions"
echo "      - 选择 'Read and write permissions'"
echo "      - 保存设置"
echo ""
echo "   2. 访问: https://github.com/$REPO/settings/secrets/actions/new"
echo "      - 添加 Secret: PACKAGE_TOKEN = $GITHUB_TOKEN"
echo ""
echo "   3. 访问: https://github.com/$REPO/settings/pages"
echo "      - 确认 Source: gh-pages 分支"
echo ""
echo "📦 Package 地址: https://github.com/$REPO/packages"
echo "📚 文档地址: https://taoseekai.github.io/mistral.rs/"
echo ""
echo "==================================="
echo "配置完成！"
echo "====================================="