const MAX_PATHS = 100

function git($, cwd, args) {
  return $.process.run(['git', '--no-optional-locks', '-c', 'core.fsmonitor=false', ...args], {
    cwd, env: { LC_ALL: 'C' }, timeoutMs: 3000,
  })
}

export async function snapshot($, root) {
  if (!root) {
    const result = await git($, await $.session.cwd(), ['rev-parse', '--show-toplevel'])
    if (result.exitCode || result.isStdoutTruncated) throw new Error('当前工作区无法定位 Git 根目录')
    root = result.stdout.replace(/\r?\n$/, '')
  }
  const status = await git($, root, ['status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all', '--no-renames'])
  if (status.exitCode || status.isStdoutTruncated) throw new Error('无法读取完整 Git 状态')
  const entries = status.stdout.split('\0').filter(Boolean)
  const head = entries.filter(entry => entry.startsWith('# branch.oid ') || entry.startsWith('# branch.head ')).join('\0')
  const paths = new Map()
  const dirty = entries.filter(entry => !entry.startsWith('# '))
  // shortcut: 大型脏工作树或子模块改动改走手动审查，避免长时或误归因的快照。
  if (dirty.length > MAX_PATHS) throw new Error('工作区变化超过 100 个路径，无法自动确定审查范围')
  for (let i = 0; i < dirty.length; i += 8) {
    const batch = await Promise.all(dirty.slice(i, i + 8).map(async entry => {
      const fields = entry.startsWith('? ')
        ? ['', entry.slice(2)]
        : entry.match(/^((?:[^ ]+ ){8})([\s\S]+)$/)?.slice(1)
      if (!fields || (!entry.startsWith('? ') && !entry.startsWith('1 '))) throw new Error('Git 状态包含未合并条目')
      const [prefix, path] = fields
      const [, , submodule, , , worktreeMode] = prefix.split(' ')
      if (submodule?.startsWith('S') || path.endsWith('/')) throw new Error('Git 状态包含子模块或嵌套仓库')
      let fingerprint = ''
      if (worktreeMode !== '000000') {
        const file = await git($, root, ['diff', '--no-index', '--no-ext-diff', '--no-textconv', '--no-color', '--full-index', '--', '/dev/null', `./${path}`])
        const mode = file.stdout.match(/^new file mode (\d+)$/m)?.[1]
        const hash = file.stdout.match(/^index 0+\.\.([a-f0-9]+)$/m)?.[1]
        if (file.exitCode !== 1 || file.stderr || !mode || !hash) throw new Error('无法计算某个 Git 路径的工作树指纹')
        fingerprint = `${mode}:${hash}`
      }
      return [path, prefix + fingerprint]
    }))
    for (const [path, fingerprint] of batch) paths.set(path, fingerprint)
  }
  return { root, head, paths }
}

export function changedPaths(before, after) {
  if (before.head !== after.head) throw new Error('任务期间 Git HEAD 或分支发生变化')
  return [...new Set([...before.paths.keys(), ...after.paths.keys()])]
    .filter(path => before.paths.get(path) !== after.paths.get(path))
    .sort()
}
