# GitHub 权限配置指南

## 1. 配置 GitHub Packages (Docker 镜像发布) 权限

### 方法 A: 配置仓库的 Actions 权限（推荐）

1. **打开仓库设置**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/settings
   - 点击左侧菜单 "Actions" → "General"

2. **配置 Workflow 权限**
   - 滚动到 "Workflow permissions" 部分
   - 选择 **"Read and write permissions"**
   - 勾选 **"Allow GitHub Actions to create and approve pull requests"**
   - 点击 "Save"

3. **配置 Package 权限**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/settings/actions
   - 在 "Workflow permissions" 下确保包含:
     - `contents: read`
     - `packages: write`
     - `id-token: write`

### 方法 B: 创建 Personal Access Token (PAT)

1. **创建新的 PAT**
   - 访问: https://github.com/settings/tokens/new
   - 或者: 个人头像 → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. **配置 Token 权限**
   ```
   Token 名称: mistral-rs-packages
   过期时间: 90 days (或根据需要)

   需要的权限:
   ✅ repo (全部)
   ✅ write:packages
   ✅ read:packages
   ✅ delete:packages (可选)
   ✅ workflow
   ```

3. **复制生成的 Token**
   - 生成后立即复制（只显示一次）
   - 格式: `ghp_xxxxxxxxxxxxxxxxxxxx`

4. **添加到仓库 Secrets**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/settings/secrets/actions
   - 点击 "New repository secret"
   - Name: `PACKAGE_TOKEN`
   - Value: 粘贴你的 PAT
   - 点击 "Add secret"

5. **更新 workflow 文件使用新 token**
   ```yaml
   - name: Log in to Container Registry
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.PACKAGE_TOKEN || secrets.GITHUB_TOKEN }}
   ```

## 2. 配置 GitHub Pages 权限

### 步骤 1: 启用 GitHub Pages

1. **访问仓库设置**
   - https://github.com/TaoSeekAI/mistral.rs/settings/pages

2. **配置 Pages 源**
   - Source: 选择 "Deploy from a branch"
   - Branch: 选择 `gh-pages` (如果没有，选择 `master`)
   - Folder: 选择 `/ (root)` 或 `/docs`
   - 点击 "Save"

3. **等待部署**
   - GitHub 会显示: "Your site is live at https://taoseekai.github.io/mistral.rs/"

### 步骤 2: 配置 Actions 部署权限

1. **创建 `gh-pages` 分支（如果不存在）**
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   echo "# Documentation" > index.html
   git add index.html
   git commit -m "Initial gh-pages commit"
   git push origin gh-pages
   git checkout master
   ```

2. **配置 GitHub Token 权限**
   - 在 Settings → Actions → General
   - Workflow permissions: 选择 "Read and write permissions"

3. **更新 docs workflow**
   创建或更新 `.github/workflows/docs.yml`:
   ```yaml
   name: Deploy Docs

   on:
     push:
       branches: [master, main]
     workflow_dispatch:

   permissions:
     contents: write
     pages: write
     id-token: write

   jobs:
     build-and-deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Setup Rust
           uses: actions-rs/toolchain@v1
           with:
             toolchain: stable

         - name: Build docs
           run: cargo doc --no-deps --workspace

         - name: Deploy to GitHub Pages
           uses: peaceiris/actions-gh-pages@v3
           with:
             github_token: ${{ secrets.GITHUB_TOKEN }}
             publish_dir: ./target/doc
             cname: docs.mistral.rs  # 可选：自定义域名
   ```

## 3. 验证配置

### 验证 Packages 权限

1. **手动触发 workflow**
   ```bash
   # 在本地推送一个 tag 来触发发布
   git tag -a v0.1.0 -m "Test release"
   git push origin v0.1.0
   ```

2. **检查 Actions 日志**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/actions
   - 查看 "Build and Publish Docker Images" workflow
   - 确认 "Log in to Container Registry" 步骤成功

3. **查看发布的包**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/packages
   - 应该能看到发布的 Docker 镜像

### 验证 Pages 权限

1. **检查部署状态**
   - 访问: https://github.com/TaoSeekAI/mistral.rs/deployments
   - 查看 github-pages 环境

2. **访问文档网站**
   - https://taoseekai.github.io/mistral.rs/
   - 或自定义域名（如果配置了）

## 4. 常见问题解决

### Package 发布失败

**错误**: `Error: buildx failed with: ERROR: denied: permission_denied`

**解决方案**:
1. 确保 workflow 有 `packages: write` 权限
2. 使用 PAT 而不是 GITHUB_TOKEN
3. 确保镜像名称格式正确: `ghcr.io/用户名/仓库名`

### Pages 部署失败

**错误**: `Error: Action failed with error: No artifacts were found`

**解决方案**:
1. 确保构建步骤生成了文档
2. 检查 `publish_dir` 路径是否正确
3. 确保有 `contents: write` 权限

### Token 权限不足

**错误**: `Error: Resource not accessible by integration`

**解决方案**:
1. Settings → Actions → General
2. 选择 "Read and write permissions"
3. 保存设置
4. 重新运行 workflow

## 5. 安全建议

1. **使用最小权限原则**
   - 只授予必要的权限
   - 定期轮换 tokens

2. **使用 Environment Secrets**
   - 为不同环境使用不同的 secrets
   - 生产环境使用更严格的审批流程

3. **监控使用情况**
   - 定期检查 Actions 日志
   - 监控包下载和访问

## 6. 命令行配置（可选）

使用 GitHub CLI 配置:

```bash
# 安装 GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# 登录
gh auth login

# 配置仓库权限
gh api repos/TaoSeekAI/mistral.rs --method PATCH \
  -f default_branch_protection=true \
  -f allow_auto_merge=true

# 创建 secret
echo "your-token-here" | gh secret set PACKAGE_TOKEN

# 启用 Pages
gh api repos/TaoSeekAI/mistral.rs/pages --method POST \
  -f source.branch=gh-pages \
  -f source.path=/
```

## 完成检查清单

- [ ] 配置 Actions 的读写权限
- [ ] 创建 Personal Access Token (如需要)
- [ ] 添加 Token 到仓库 Secrets
- [ ] 启用 GitHub Pages
- [ ] 配置 Pages 源分支
- [ ] 更新 workflow 文件权限
- [ ] 测试 Docker 镜像发布
- [ ] 测试文档部署
- [ ] 验证所有 CI/CD 流程

完成这些配置后，你的 CI/CD 流程应该能够正常工作了！