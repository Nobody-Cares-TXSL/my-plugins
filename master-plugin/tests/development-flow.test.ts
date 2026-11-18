import { expect, test } from 'claude-code/testing'
import type { AgentSpawnInput, On, TurnCompleteInput } from 'claude-code'
import type { Engine } from 'claude-code/testing'
// @ts-expect-error 仓库的 Mod 是未生成声明的 JS。
import { register as registerFlow } from '../hooks/development-flow.js'

const BAND = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 8,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 8 },
  view: {},
}

function mount($: Engine, on: On) {
  on('ui.render', ($, e) => $.ui.resolve(e).Text({ children: ['base'] }))
  return $.ui.mount({ plugin: 'master-plugin', surface: 'terminal', component: 'AbovePrompt', props: BAND })
}

function draftStubs(on: On, initial: string, toolNames = ['Read', 'Glob', 'Grep']) {
  let draft = initial
  const submitted: string[] = []
  const toasts: string[] = []
  on('prompt.read', () => ({ value: { text: draft, cursor: draft.length } }))
  on('prompt.fill', (_$, e) => {
    draft = e.text
    return { isFilled: true, text: draft, cursor: draft.length }
  })
  on('prompt.submit', (_$, e) => {
    submitted.push(e.text)
    return { text: e.text }
  })
  on('ui.toast', (_$, e) => { toasts.push(e.text); return { value: undefined } })
  on('turn.complete', (_$, e) => ({ text: e.answer }))
  on('agent.list', () => ({ value: [] }))
  on('tool.list', () => ({ value: toolNames.map(name => ({ name, description: '', mcp: false })) }))
  on('session.cwd', () => ({ value: '/fixture' }))
  on('process.run', () => ({ value: { exitCode: 1, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('ui.log', () => ({ value: undefined }))
  return { submitted, toasts, get draft() { return draft } }
}

function completion(agentId: string, answer: string): TurnCompleteInput {
  return { agentId, reason: 'answer', answer, durationMs: 1, isAborted: false, turnId: `turn-${agentId}` }
}

function nativeSpawn(type: string, permissionMode = 'default'): AgentSpawnInput {
  return {
    tool_use_id: 'call', subagentType: type, description: '原生任务', prompt: '原生草稿',
    provider: { plugin: 'engine', tier: 'core' }, background: true, fork: false,
    parentModel: 'parent-test', permissionMode,
  }
}

test('探索直接派发原始草稿并注入说明；宿主未启动代理时不生成汇总', async ($, on) => {
  const original = '  查找校验入口\n不要修改代码  '
  const draft = draftStubs(on, original)
  const spawns: Array<{ subagent_type?: string; prompt: string; model?: string }> = []
  on('fs.read', (_$, e) => ({ value: e.path.endsWith('/explore.md') ? '探索补充说明' : '' }))
  on('agent.spawn', (_$, e) => {
    // 测试宿主用原生 Agent 工具入参替代插件发起的 spawn。
    spawns.push(e as unknown as (typeof spawns)[number])
    return { model: 'configured-test' }
  })
  const ui = await mount($, on)
  expect(await ui.find({ key: 'flow-explore' })).toBeDefined()
  expect(spawns).toHaveLength(0)
  await ui.press({ key: 'flow-explore' })
  expect(spawns).toHaveLength(1)
  expect(spawns[0]?.subagent_type).toBe('Explore')
  expect(spawns[0]?.prompt).toBe(`${original}\n\n---\n\n探索补充说明`)
  expect(spawns[0]?.model).toBeUndefined()
  expect(draft.toasts).toEqual(['子代理未启动。'])
  await $.turn.complete(completion('unrelated', '无关结果'))
  expect(draft.submitted).toEqual([])
  expect(draft.draft).toBe(original)
  await ui.unmount()
})

test('缺少搜索工具时不启动 Explore，并提示如何恢复', async ($, on) => {
  const draft = draftStubs(on, '查找校验入口', ['Read', 'Bash'])
  on('agent.spawn', () => { throw new Error('不应派发') })
  const ui = await mount($, on)
  await ui.press({ key: 'flow-explore' })
  expect(draft.toasts[0]).toContain('缺少 Glob、Grep')
  expect(draft.toasts[0]).toContain('--allowedTools Glob Grep')
  expect(draft.draft).toBe('查找校验入口')
  await ui.unmount()
})

test('普通 Explore 和 Plan 的原生派发不加插件说明', async ($, on) => {
  const received: string[] = []
  on('fs.read', () => { throw new Error('不应读取说明') })
  on('agent.spawn', (_$, e) => { received.push(e.prompt); return { agentId: 'native', model: 'test' } })
  await $.agent.spawn(nativeSpawn('Explore', 'plan'))
  await $.agent.spawn(nativeSpawn('Plan', 'plan'))
  expect(received).toEqual(['原生草稿', '原生草稿'])
})

test('空草稿不执行，角色说明不可用时拒绝启动并解除按钮占用', async ($, on) => {
  let text = '\n  '
  let spawns = 0
  const toasts: string[] = []
  on('prompt.read', () => ({ value: { text, cursor: text.length } }))
  on('ui.toast', (_$, e) => { toasts.push(e.text); return { value: undefined } })
  on('agent.list', () => ({ value: [] }))
  on('tool.list', () => ({ value: ['Read', 'Glob', 'Grep'].map(name => ({ name, description: '', mcp: false })) }))
  on('ui.log', () => ({ value: undefined }))
  on('fs.read', () => ({ deny: 'missing' }))
  on('agent.spawn', () => { spawns++; return { agentId: 'fake', model: 'test' } })
  const ui = await mount($, on)
  await ui.press({ key: 'flow-explore' })
  text = '查一下校验入口'
  await ui.press({ key: 'flow-explore' })
  expect(spawns).toBe(0)
  expect(toasts.some(t => t.includes('写下任务'))).toBe(true)
  expect(toasts.some(t => t.includes('无法读取'))).toBe(true)
  await ui.unmount()
})

test('实现授权只派发给 general-purpose，原草稿保留', async ($, on) => {
  const original = '修改 lib/check.js 并补回归测试'
  const draft = draftStubs(on, original)
  on('fs.read', (_$, e) => ({ value: e.path.endsWith('/general-purpose.md') ? '实现补充说明' : '' }))
  on('agent.spawn', (_$, e) => {
    expect(e).toMatchObject({ subagent_type: 'general-purpose' })
    expect(e.prompt).toBe(`${original}\n\n---\n\n实现补充说明`)
    expect(e.model).toBeUndefined()
    return { model: 'configured-test' }
  })
  const ui = await mount($, on)
  await ui.press({ key: 'flow-implement' })
  expect(draft.submitted).toHaveLength(0)
  expect(draft.toasts).toEqual(['无法建立 Git 基线；实现仍会启动，但不会自动审查 diff。', '子代理未启动。'])
  expect(draft.draft).toBe(original)
  await ui.unmount()
})

test('原生启动确认后关闭重复派发，强制探索只读，并按代理 ID 回交结果', async () => {
  // Mod 测试宿主不会给替身创建真实 agentId；在此模拟原生核心的启动回执。
  const hooks = new Map<string, (...args: any[]) => any>()
  const buttons = new Map<string, () => Promise<void>>()
  const followups: string[] = []
  let starts = 0
  let mode = 'default'
  let processStatus = 'running'
  let fileVersion = 'a'
  let releaseLaunch: (() => void) | undefined
  let notifyLaunch: (() => void) | undefined
  const proceed = async (e: unknown) => e
  const $ = {
    plugin: { name: 'master-plugin', root: '/plugin' },
    prompt: {
      read: async () => ({ text: '修复 lib/check.js 空输入校验' }),
      submit: async ({ text }: { text: string }) => { followups.push(text); return { text } },
    },
    fs: { read: async () => '补充说明' },
    session: { cwd: async () => '/fixture' },
    process: {
      run: async (args: string[]) => {
        if (args.includes('rev-parse')) return { exitCode: 0, stdout: '/fixture\n' }
        if (args.includes('status')) {
          const before = '# branch.oid same\0# branch.head main\0? existing.txt\0? edited.txt\0'
          const indexed = `1 M. N... 100644 100644 100644 abc ${fileVersion} staged.txt\0`
          return { exitCode: 0, stdout: before + indexed + (fileVersion === 'b' ? '? new file\nname.ts\0' : '') }
        }
        const hash = args.at(-1) === './edited.txt' ? fileVersion : 'c'
        return { exitCode: 1, stdout: `new file mode 100644\nindex 0000..${hash}\n`, stderr: '' }
      },
    },
    tool: { list: async () => ['Read', 'Glob', 'Grep'].map(name => ({ name })) },
    agent: {
      spawn: async ({ subagentType }: { subagentType: string }) => {
        const event = nativeSpawn(subagentType, mode)
        if (notifyLaunch) {
          const held = new Promise<void>(resolve => { releaseLaunch = resolve })
          notifyLaunch()
          await held
        }
        const next = Object.assign(() => ({ model: 'test', agentId: `agent-${++starts}` }), {
          origin: { plugin: 'master-plugin' },
        })
        return hooks.get('agent.spawn')!($, event, next)
      },
      list: async () => starts ? [{ id: `agent-${starts}`, status: processStatus, spawnedBy: 'master-plugin' }] : [],
    },
    ui: {
      invalidate() {}, toast() {}, log() {},
      resolve: () => ({ Box() {}, Button: ({ key, onPress }: { key: string; onPress: () => Promise<void> }) => buttons.set(key, onPress) }),
    },
  }
  registerFlow((event: string, matcher: unknown, handler?: (...args: any[]) => any) => {
    hooks.set(event, handler ?? (matcher as (...args: any[]) => any))
    return { catch: (fallback: (...args: any[]) => any) => hooks.set(`${event}.catch`, fallback) }
  })
  await hooks.get('ui.render')!($, { surface: 'terminal', props: BAND }, () => undefined)
  await buttons.get('flow-explore')!()
  await buttons.get('flow-implement')!()
  expect(starts).toBe(1)
  const call = hooks.get('tool.call')!
  for (const tool of ['Write', 'Edit', 'Bash', 'mcp__fixture__write']) {
    expect(await call($, { agentId: 'agent-1', tool }, proceed)).toMatchObject({ deny: expect.any(String) })
  }
  for (const tool of ['Read', 'SubagentHandback']) {
    const allowed = { agentId: 'agent-1', tool }
    expect(await call($, allowed, proceed)).toBe(allowed)
  }
  const other = { agentId: 'other', tool: 'Edit' }
  expect(await call($, other, proceed)).toBe(other)
  const fallback = hooks.get('tool.call.catch')!
  const failedBeforeNext = Object.assign(proceed, { called: false })
  expect(await fallback($, { agentId: 'agent-1', tool: 'Write' }, failedBeforeNext)).toMatchObject({ deny: expect.any(String) })
  expect(await fallback($, other, failedBeforeNext)).toBe(other)
  const done = hooks.get('turn.complete')!
  await done($, completion('different', '无关结果'), proceed)
  expect(followups).toEqual([])
  processStatus = 'completed'
  await done($, completion('agent-1', '证据见 lib/check.js:20'), proceed)
  expect(followups[0]).toContain('证据见 lib/check.js:20')
  mode = 'plan'
  await buttons.get('flow-implement')!()
  expect(starts).toBe(1)
  mode = 'default'
  await buttons.get('flow-implement')!()
  expect(starts).toBe(2)
  processStatus = 'killed'
  await buttons.get('flow-implement')!()
  expect(starts).toBe(3)
  fileVersion = 'b'
  await done($, completion('agent-3', '代理自报只改了 other.js'), proceed)
  expect(followups[1]).toContain('不要自动修改')
  const input = JSON.parse(followups[1]!.split('\n\n').at(-1)!)
  expect(input.scope.paths).toEqual(['edited.txt', 'new file\nname.ts', 'staged.txt'])
  expect(input.report).toBe('代理自报只改了 other.js')

  processStatus = 'completed'
  const enteredLaunch = new Promise<void>(resolve => { notifyLaunch = resolve })
  const late = buttons.get('flow-explore')!()
  await enteredLaunch
  const unrelated = call($, other, proceed)
  await hooks.get('session.end')!($, { reason: 'resume' }, proceed)
  releaseLaunch!()
  await late
  expect(await unrelated).toBe(other)
  await done($, completion('agent-4', '旧会话迟到报告'), proceed)
  expect(followups).toHaveLength(2)
})

test('Plan Mode 只提醒主对话在落笔前 Read，不读取正文或改变子代理的提醒', async ($, on) => {
  let fileReads = 0
  on('fs.read', () => { fileReads++; return { value: '计划说明正文' } })
  on('prompt.attachment', (_$, e) => ({ text: e.text }))
  const enter = { type: 'plan_mode', text: '原生 Plan Mode', origin: { kind: 'engine' } } as const
  const main = await $.prompt.attachment(enter)
  expect(main.text).toContain('原生 Plan Mode')
  expect(main.text).toContain('真正准备撰写最终计划时')
  expect(main.text).toContain('/hooks/subagent-notes/plan.md')
  expect(main.text).not.toContain('计划说明正文')
  expect((await $.prompt.attachment({ ...enter, type: 'plan_mode_reentry' })).text).toContain('先单独通过 Read')
  expect((await $.prompt.attachment({ ...enter, agentId: 'child' })).text).toBe(enter.text)
  expect((await $.prompt.attachment({ ...enter, type: 'plan_mode_exit' })).text).toBe(enter.text)
  expect(fileReads).toBe(0)
})
