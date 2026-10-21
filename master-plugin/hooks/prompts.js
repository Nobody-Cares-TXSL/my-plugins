const PANE = 'prompt-library'

// 这些值只用于当前面板；重新打开命令时从磁盘加载，不保存用户数据。
let prompts = []
let directory = ''
let query = ''
let selected = ''
let problem = ''
let folders = ['']
let folder = ''
let notice = ''

function extractFrontmatter(text) {
  const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/)
  if (!/^---[ \t]*$/.test(lines[0])) return null
  for (let index = 1; index < lines.length; index += 1) {
    if (/^(---|\.\.\.)[ \t]*$/.test(lines[index])) {
      return lines.slice(1, index).join('\n')
    }
  }
  return null
}

async function readDirectory($, relativeDirectory, errors) {
  const prefix = relativeDirectory ? relativeDirectory + '/' : ''
  const path = directory.replace(/\/$/, '') + '/' + relativeDirectory
  let entries
  try {
    entries = await $.fs.list(path)
  } catch (error) {
    errors.push((relativeDirectory || directory) + '：' + error.message)
    return
  }
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const file = prefix + entry.name
    if (entry.isLink) continue
    if (entry.kind === 'dir') {
      folders.push(file)
      await readDirectory($, file, errors)
    } else if (entry.kind === 'file' && /\.md$/i.test(entry.name)) {
      try {
        const text = await $.fs.read(directory.replace(/\/$/, '') + '/' + file)
        if (!text.trim()) continue
        const heading = text.match(/^#\s+(.+)$/m)
        prompts.push({
          name: heading ? heading[1].trim() : entry.name.replace(/\.md$/i, ''),
          file, folder: relativeDirectory, text, frontmatter: extractFrontmatter(text),
        })
      } catch (error) {
        errors.push(file + '：' + error.message)
      }
    }
  }
}

async function loadLibrary($, configuredDirectory) {
  prompts = []
  folders = ['']
  problem = ''
  notice = ''
  try {
    directory = configuredDirectory.trim()
    if (directory.startsWith('~/')) {
      const home = await $.env.get('HOME')
      if (!home) throw new Error('无法读取 HOME，请将 Prompt 库目录配置为绝对路径。')
      directory = home + directory.slice(1)
    }
    if (!directory.startsWith('/')) {
      throw new Error('请将 Prompt 库目录配置为绝对路径，或使用 ~/ 开头的路径。')
    }
    directory = directory.replace(/\/+$/, '') || '/'
    if (!await $.fs.exists(directory)) {
      throw new Error('目录不存在：' + directory + '。请创建目录并放入 Markdown 提示词。')
    }
    const errors = []
    await readDirectory($, '', errors)
    problem = errors.join('\n')
  } catch (error) {
    problem = error.message
  }
  if (!folders.includes(folder)) folder = ''
  $.ui.invalidate('ui.render')
}

function matchingPrompts() {
  const keyword = query.trim().toLowerCase()
  return prompts.filter(prompt =>
    keyword ? (prompt.name + '\n' + prompt.file + '\n' + prompt.text).toLowerCase().includes(keyword)
      : prompt.folder === folder)
}

async function fillPrompt($, prompt, mode) {
  try {
    const result = await $.prompt.fill({ text: prompt.text, mode })
    if (result.isFilled) {
      notice = '已填入：' + prompt.name + '。面板保持打开，可继续选择提示词。'
      $.ui.invalidate('ui.render')
    } else {
      $.ui.toast('当前无法填入输入框，请关闭其他对话框后重试。')
    }
  } catch (error) {
    $.ui.toast('填入失败：' + error.message)
  }
}

export function register(on, options) {
  const configuredDirectory = options.promptsDirectory || '~/.claude/prompts'

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'prompts',
      description: '搜索、预览本地 Markdown 提示词，并填入输入框',
      argumentHint: '[关键词]',
      immediate: true,
    })
    return next(e)
  })

  on('command.run', { command: 'prompts' }, async ($, e) => {
    query = (e.args || '').trim()
    selected = ''
    folder = ''
    await loadLibrary($, configuredDirectory)
    const surfaces = await $.session.surfaces()
    if (!surfaces.includes('terminal') && !surfaces.includes('desktop')) {
      const names = (query ? matchingPrompts() : prompts).map(prompt => '- ' + prompt.name + ' (' + prompt.file + ')')
      return { text: [problem, 'Prompt 库：' + directory, ...names,
        '请在 Claude Code 终端或 Desktop 中使用 /prompts 打开面板并填入输入框。',
      ].filter(Boolean).join('\n') }
    }
    await $.ui.open({ id: PANE, title: 'Prompt Library', focus: true, closeOnEscape: true })
    return {}
  })

  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== PANE || (e.surface !== 'terminal' && e.surface !== 'desktop')) {
      return next(e)
    }
    const { Box, Text, Input, Code, Button } = $.ui.resolve(e)
    const matches = matchingPrompts()
    const current = matches.find(prompt => prompt.file === selected) || matches[0]
    const childFolders = folders.filter(path => path &&
      path.split('/').slice(0, -1).join('/') === folder)

    return Box({ flexDirection: 'column', gap: 1, children: [
      Text({ bold: true, children: ['Prompt Library'] }),
      Text({ dimColor: true, children: [directory] }),
      Input({
        key: 'search', label: '搜索', placeholder: '名称、文件名或内容',
        value: query, autoFocus: true, submitLabel: '搜索',
        onInput: value => { query = value; $.ui.invalidate('ui.render') },
        onSubmit: value => { query = value; $.ui.invalidate('ui.render') },
      }),
      problem && Text({ color: 'yellow', children: [problem] }),
      notice && Text({ color: 'green', children: [notice] }),
      Text({ children: [query.trim() ? '搜索全部文件夹' : '当前文件夹：/' + folder] }),
      folder && Button({
        key: 'parent-folder', label: '返回上一级',
        onPress: () => {
          folder = folder.split('/').slice(0, -1).join('/')
          query = ''; selected = ''; notice = ''
          $.ui.invalidate('ui.render')
        },
      }),
      !query.trim() && Box({ flexDirection: 'column', children: childFolders.map(path => Button({
        key: 'folder:' + path, label: '[目录] ' + path.split('/').pop(), plain: true,
        onPress: () => {
          folder = path; selected = ''; notice = ''
          $.ui.invalidate('ui.render')
        },
      })) }),
      Text({ dimColor: true, children: ['匹配 ' + matches.length + ' / ' + prompts.length] }),
      matches.length > 0 ? Box({ flexDirection: 'column', children: matches.map(prompt => Button({
        key: 'prompt:' + prompt.file,
        label: (prompt.file === current.file ? '> ' : '  ') + prompt.name + ' · ' + prompt.file,
        plain: true,
        onPress: () => { selected = prompt.file; notice = ''; $.ui.invalidate('ui.render') },
      })) }) : Text({ children: [query.trim() ? '没有匹配的提示词。' : '当前文件夹暂无提示词，可进入子文件夹或放入非空 .md 文件后刷新。'] }),
      current && (current.frontmatter === null
        ? Text({ dimColor: true, children: ['文件未包含完整的开头 frontmatter。'] })
        : current.frontmatter.trim()
          ? Code({ source: current.frontmatter, language: 'yaml' })
          : Text({ dimColor: true, children: ['frontmatter 为空。'] })),
      current && Box({ gap: 1, children: [
        Button({ key: 'insert', onPress: () => fillPrompt($, current, 'insert'), children: ['插入光标处'] }),
        Button({ key: 'append', onPress: () => fillPrompt($, current, 'append'), children: ['追加到末尾'] }),
        Button({ key: 'replace', onPress: () => fillPrompt($, current, 'replace'), children: ['替换输入内容'] }),
      ] }),
      Box({ gap: 1, children: [
        Button({ key: 'refresh', onPress: () => loadLibrary($, configuredDirectory), children: ['刷新'] }),
        Button({ key: 'close', onPress: () => $.ui.close({ id: PANE }), children: ['关闭'] }),
      ] }),
      Text({ dimColor: true, children: ['点击目录或提示词选择。填入后面板保持打开；Esc 关闭面板并返回输入框。Tab 切换控件。'] }),
    ] })
  })
}
