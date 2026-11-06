import { expect, mock, test } from 'claude-code/testing'

const VIEWPORT = { columns: 120, rows: 40, isFullscreen: true }
const STAT_FILE = { kind: 'file', size: 1, mtimeMs: 0, isLink: false }

function mountMessage($: any, on: any, text: string, requestId = 'assistant-1') {
  on('ui.render', ($: any, e: any) => {
    const { Text } = $.ui.resolve(e)
    return Text({ children: ['base message'] })
  })
  return $.ui.mount({
    plugin: 'master-plugin',
    surface: 'terminal',
    component: 'AssistantMessage',
    requestId,
    viewport: VIEWPORT,
    props: { text, isFirstOfReply: true },
  })
}

test('不同目录的同名 HTML 文件分别展示，同一文件的重复锚点只展示一次', async ($, on) => {
  const statPaths: string[] = []
  on('session.cwd', () => ({ value: '/workspace' }))
  mock.env(on, { HOME: '/home/test' })
  on('fs.stat', (_$: unknown, e: { path: string }) => {
    statPaths.push(e.path)
    return { value: STAT_FILE }
  })

  const ui = await mountMessage(
    $,
    on,
    '[src](src/a/index.html#overview) [public](public/a/index.html#overview) [again](src/a/index.html#details)',
  )
  const links = await ui.find({ key: 'html-open' })

  expect(links).toBeDefined()
  expect(links?.text).toContain('src/a/index.html')
  expect(links?.text).toContain('public/a/index.html')
  expect(statPaths).toEqual([
    '/workspace/src/a/index.html',
    '/workspace/public/a/index.html',
  ])

  await ui.unmount()
})

test('重复渲染复用 cwd 与文件状态缓存，会话结束后清理缓存', async ($, on) => {
  let cwdCalls = 0
  let statCalls = 0
  on('session.cwd', () => {
    cwdCalls++
    return { value: '/workspace' }
  })
  mock.env(on, { HOME: '/home/test' })
  on('fs.stat', () => {
    statCalls++
    return { value: STAT_FILE }
  })
  on('session.end', (_$: unknown, e: { sessionId: string }) => ({
    sessionId: e.sessionId,
  }))

  const ui = await mountMessage($, on, 'report.html')
  expect(cwdCalls).toBe(1)
  expect(statCalls).toBe(1)

  await ui.redraw()
  expect(cwdCalls).toBe(1)
  expect(statCalls).toBe(1)

  await $.session.end({
    reason: 'clear',
    sessionId: 'session-before-clear',
    resume: { id: 'session-before-clear' },
  })
  await ui.redraw()

  expect(cwdCalls).toBe(2)
  expect(statCalls).toBe(2)
  await ui.unmount()
})

test('文件状态缓存有容量上限，最久未使用的路径会被淘汰', async ($, on) => {
  const statPaths: string[] = []
  on('session.cwd', () => ({ value: '/workspace' }))
  mock.env(on, { HOME: '/home/test' })
  on('fs.stat', (_$: unknown, e: { path: string }) => {
    statPaths.push(e.path)
    return { value: STAT_FILE }
  })

  const batchText = (batch: number) =>
    Array.from({ length: 20 }, (_, index) => `batch-${batch}/file-${index}.html`).join(' ')

  const ui = await mountMessage($, on, batchText(0))
  for (let batch = 1; batch < 52; batch++) {
    await ui.redraw({ text: batchText(batch), isFirstOfReply: true })
  }

  const firstPath = '/workspace/batch-0/file-0.html'
  expect(statPaths.filter((path) => path === firstPath)).toHaveLength(1)

  await ui.redraw({ text: 'batch-0/file-0.html', isFirstOfReply: true })
  expect(statPaths.filter((path) => path === firstPath)).toHaveLength(2)
  await ui.unmount()
})
